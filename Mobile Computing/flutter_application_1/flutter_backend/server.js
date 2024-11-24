const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs'); // Für Passwort-Hashing
const nodemailer = require('nodemailer'); // Added nodemailer
const app = express();
const port = process.env.PORT || 3001;

// Load environment variables from .env file
dotenv.config();

// Definiere die CORS-Optionen
const corsOptions = {
  origin: 'http://localhost:3000', // Passe den Port an, auf dem deine Flutter-App läuft
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

// Verwende die CORS-Middleware mit den Optionen
app.use(cors(corsOptions));

// Behandle Preflight-Anfragen
app.options('*', cors(corsOptions));

// Middleware
app.use(express.json());

// Create a MySQL pool
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Create email transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD
  }
});

// Test Route
app.get('/', (req, res) => {
  res.send('Backend Server is Running');
});

// Create or get existing tag
app.post('/api/tags', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { name } = req.body;
    
    // Check if tag already exists
    const [existingTag] = await connection.query(
      'SELECT id FROM tags WHERE name = ?',
      [name]
    );

    if (existingTag.length > 0) {
      return res.status(409).json({ 
        id: existingTag[0].id,
        message: 'Tag already exists' 
      });
    }

    // Create new tag
    const [result] = await connection.query(
      'INSERT INTO tags (name, create_time) VALUES (?, NOW())',
      [name]
    );

    res.status(201).json({
      id: result.insertId,
      name: name,
      message: 'Tag created successfully'
    });
  } catch (error) {
    console.error('Error creating tag:', error);
    res.status(500).json({ message: 'Error creating tag', error: error.message });
  } finally {
    connection.release();
  }
});

// Get tag by name
app.get('/api/tags/byName/:name', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const [tag] = await connection.query(
      'SELECT * FROM tags WHERE name = ?',
      [req.params.name]
    );

    if (tag.length === 0) {
      return res.status(404).json({ message: 'Tag not found' });
    }

    res.json(tag[0]);
  } catch (error) {
    console.error('Error fetching tag:', error);
    res.status(500).json({ message: 'Error fetching tag', error: error.message });
  } finally {
    connection.release();
  }
});

// Associate tags with training
app.post('/api/training-tags', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { trainingId, tagIds } = req.body;

    // Insert all tag associations
    const values = tagIds.map(tagId => [trainingId, tagId]);
    await connection.query(
      'INSERT INTO training_tags (training_id, tag_id) VALUES ?',
      [values]
    );

    res.status(201).json({ message: 'Tags associated with training successfully' });
  } catch (error) {
    console.error('Error associating tags:', error);
    res.status(500).json({ message: 'Error associating tags', error: error.message });
  } finally {
    connection.release();
  }
});

// Get tags for a training
app.get('/api/training/:trainingId/tags', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const [tags] = await connection.query(
      `SELECT t.* 
       FROM tags t
       JOIN training_tags tt ON t.id = tt.tag_id
       WHERE tt.training_id = ?`,
      [req.params.trainingId]
    );

    res.json(tags);
  } catch (error) {
    console.error('Error fetching training tags:', error);
    res.status(500).json({ message: 'Error fetching training tags', error: error.message });
  } finally {
    connection.release();
  }
});

app.get('/api/users/:userId/bookings', async (req, res) => {
  const userId = req.params.userId;
  const connection = await pool.getConnection();

  try {
    const [bookings] = await connection.query(
      `SELECT 
        b.training_id,
        s.titel AS training_name,
        s.beschreibung,
        s.ort,
        s.max_teilnehmer,
        s.dozent_id,
        d.vorname AS dozent_vorname,
        d.nachname AS dozent_nachname,
        d.email AS dozent_email,
        GROUP_CONCAT(DISTINCT DATE_FORMAT(ss.datum, '%Y-%m-%d') ORDER BY ss.datum ASC) AS dates,
        COUNT(DISTINCT b2.id) AS booked_count,
        MIN(ss.datum) as start_date,
        MAX(ss.datum) as end_date,
        COUNT(DISTINCT ss.datum) as session_count,
        GROUP_CONCAT(DISTINCT t.name) as tag_names
      FROM bookings b
      JOIN schulungen s ON b.training_id = s.id
      LEFT JOIN dozenten d ON s.dozent_id = d.id
      LEFT JOIN schulung_sessions ss ON s.id = ss.schulung_id
      LEFT JOIN bookings b2 ON s.id = b2.training_id
      LEFT JOIN schulungen_tags st ON s.id = st.schulung_id
      LEFT JOIN tags t ON st.tag_id = t.id
      WHERE b.user_id = ?
      GROUP BY b.training_id
      ORDER BY s.titel ASC`,
      [userId]
    );

    // Get sessions for each training
    const userBookings = await Promise.all(bookings.map(async (booking) => {
      const [sessions] = await connection.execute(
        'SELECT * FROM schulung_sessions WHERE schulung_id = ? ORDER BY datum',
        [booking.training_id]
      );

      return {
        ...booking,
        dates: booking.dates ? booking.dates.split(',') : [],
        start_date: booking.start_date ? booking.start_date.toISOString().split('T')[0] : null,
        end_date: booking.end_date ? booking.end_date.toISOString().split('T')[0] : null,
        is_multi_day: booking.session_count > 1,
        tags: booking.tag_names ? booking.tag_names.split(',') : [],
        sessions: sessions,
        start_times: sessions.map(s => s.startzeit),
        end_times: sessions.map(s => s.endzeit)
      };
    }));

    res.json(userBookings);
  } catch (error) {
    console.error('Fehler beim Abrufen der Buchungen des Nutzers:', error);
    res.status(500).json({ error: 'Fehler beim Abrufen der Buchungen' });
  } finally {
    connection.release();
  }
});

app.get('/api/trainings', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    console.log('Fetching trainings...');
    const [trainings] = await connection.execute(`
      SELECT 
        s.*,
        d.vorname as dozent_vorname,
        d.nachname as dozent_nachname,
        d.email as dozent_email,
        GROUP_CONCAT(DISTINCT t.name) as tag_names,
        (SELECT COUNT(*) FROM bookings b WHERE b.training_id = s.id) as booked_count
      FROM schulungen s
      LEFT JOIN dozenten d ON s.dozent_id = d.id
      LEFT JOIN schulungen_tags st ON s.id = st.schulung_id
      LEFT JOIN tags t ON st.tag_id = t.id
      GROUP BY s.id
    `);
    
    console.log('Raw trainings:', trainings);

    // Get sessions for each training
    for (let training of trainings) {
      const [sessions] = await connection.execute(
        'SELECT * FROM schulung_sessions WHERE schulung_id = ? ORDER BY datum',
        [training.id]
      );
      
      // Format dates for frontend
      training.dates = sessions.map(session => session.datum);
      training.start_date = sessions.length > 0 ? sessions[0].datum : null;
      training.end_date = sessions.length > 0 ? sessions[sessions.length - 1].datum : null;
      training.sessions = sessions;
      
      // Convert tag_names string to array
      training.tags = training.tag_names ? training.tag_names.split(',') : [];
      delete training.tag_names;
      
      // Ensure booked_count is a number
      training.booked_count = parseInt(training.booked_count) || 0;
      
      console.log(`Training ${training.id} has ${training.booked_count} bookings`);
    }

    console.log('Processed trainings:', trainings);
    res.json(trainings);
  } catch (error) {
    console.error('Error in /api/trainings:', error);
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

app.post('/api/trainings', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { training_name, description, location, max_participants, lecturer_id, dates, tags, pauses, start_times, end_times } = req.body;
    
    // Begin a transaction
    await connection.beginTransaction();

    // Insert the training (without tags)
    const [result] = await connection.execute(
      'INSERT INTO schulungen (titel, beschreibung, ort, max_teilnehmer, dozent_id, gesamt_startdatum, gesamt_enddatum) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [training_name, description, location, max_participants, lecturer_id, dates[0], dates[dates.length - 1]]
    );

    const trainingId = result.insertId;

    // Insert tag relationships
    if (tags && tags.length > 0) {
      const tagValues = tags.map(tagId => [trainingId, tagId]);
      await connection.query(
        'INSERT INTO schulungen_tags (schulung_id, tag_id) VALUES ?',
        [tagValues]
      );
    }

    // Insert training sessions with start and end times
    const sessionInserts = dates.map((date, index) => [
      trainingId, 
      date, 
      (start_times && start_times[index]) || '09:00:00',  // Use provided start time or default
      (end_times && end_times[index]) || '17:00:00',    // Use provided end time or default
      'normal', 
      null
    ]);
    
    await connection.query(
      'INSERT INTO schulung_sessions (schulung_id, datum, startzeit, endzeit, typ, bemerkung) VALUES ?',
      [sessionInserts]
    );

    // Insert pauses
    if (pauses && pauses.length > 0) {
      const pauseInserts = pauses.map(pause => [trainingId, pause.start, pause.end, 'Pausengrund']);
      await connection.query(
        'INSERT INTO schulung_pause (schulung_id, start_datum, end_datum, grund) VALUES ?',
        [pauseInserts]
      );
    }

    // Commit the transaction
    await connection.commit();
    res.status(201).send({ message: 'Schulung hinzugefügt' });
  } catch (error) {
    // Rollback on error
    await connection.rollback();
    console.error('Fehler beim Hinzufügen der Schulung:', error);
    res.status(500).send({ message: 'Fehler beim Hinzufügen der Schulung' });
  } finally {
    // Release the connection
    connection.release();
  }
});

// Update a training by ID
app.put('/api/trainings/:id', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const trainingId = req.params.id;
    const { training_name, description, location, max_participants, lecturer_id, dates, tags, pauses, start_times, end_times } = req.body;
    
    // Format dates for MySQL (YYYY-MM-DD format)
    const formattedStartDate = new Date(dates[0]).toISOString().split('T')[0];
    const formattedEndDate = new Date(dates[dates.length - 1]).toISOString().split('T')[0];
    
    // Begin a transaction
    await connection.beginTransaction();

    // Update the training basic info
    await connection.execute(
      'UPDATE schulungen SET titel = ?, beschreibung = ?, ort = ?, max_teilnehmer = ?, dozent_id = ?, gesamt_startdatum = ?, gesamt_enddatum = ? WHERE id = ?',
      [training_name, description, location, max_participants, lecturer_id, formattedStartDate, formattedEndDate, trainingId]
    );

    // Delete existing tag relationships
    await connection.execute('DELETE FROM schulungen_tags WHERE schulung_id = ?', [trainingId]);

    // Insert new tag relationships
    if (tags && tags.length > 0) {
      // First, get tag IDs from tag names
      const tagPlaceholders = tags.map(() => '?').join(',');
      const [tagRows] = await connection.execute(
        `SELECT id, name FROM tags WHERE name IN (${tagPlaceholders})`,
        tags
      );
      
      if (tagRows.length > 0) {
        const tagValues = tagRows.map(tag => [trainingId, tag.id]);
        await connection.query(
          'INSERT INTO schulungen_tags (schulung_id, tag_id) VALUES ?',
          [tagValues]
        );
      }
    }

    // Delete existing sessions
    await connection.execute('DELETE FROM schulung_sessions WHERE schulung_id = ?', [trainingId]);

    // Insert updated training sessions with formatted dates
    const sessionInserts = dates.map((date, index) => [
      trainingId, 
      new Date(date).toISOString().split('T')[0], // Format date for MySQL
      (start_times && start_times[index]) || '09:00:00',
      (end_times && end_times[index]) || '17:00:00',
      'normal', 
      null
    ]);
    
    await connection.query(
      'INSERT INTO schulung_sessions (schulung_id, datum, startzeit, endzeit, typ, bemerkung) VALUES ?',
      [sessionInserts]
    );

    // Commit the transaction
    await connection.commit();
    
    res.json({ message: 'Training successfully updated', id: trainingId });
  } catch (error) {
    await connection.rollback();
    console.error('Error updating training:', error);
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

// Delete a training by ID
app.delete('/api/trainings/:id', async (req, res) => {
  const { id } = req.params;

  try {
    // Lösche die Schulung und die zugehörigen Daten
    const [result] = await pool.query('DELETE FROM schulungen WHERE id = ?', [id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Training not found' });
    }

    res.json({ message: 'Training deleted' });
  } catch (error) {
    console.error('Error deleting training:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// User Registration
app.post('/api/register', async (req, res) => {
  const { email, password, role, first_name, last_name, company, phone } = req.body; // Weitere Eigenschaften können hinzugefügt werden
  try {
    // Insert the user into the database
    const hashedPassword = await bcrypt.hash(password, 10); // bcrypt for secure password storage

    const [result] = await pool.query(
      `INSERT INTO users (first_name, last_name, company, role, email, phone, password)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [first_name, last_name, company, role, email, phone, hashedPassword] // Hash passwort for security
    );
    res.status(201).json({ 
      message: 'User registered successfully', 
      userId: result.insertId 
    });
  } catch (error) {
    console.error('Error during registration:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Benutzer anmelden
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'E-Mail und Passwort sind erforderlich' });
  }

  try {
    // Benutzer aus der Datenbank abrufen
    const [rows] = await pool.query('SELECT id, email, password, role FROM users WHERE email = ?', [email]);

    if (rows.length === 0) {
      // Benutzer existiert nicht
      return res.status(401).json({ error: 'Ungültige Anmeldeinformationen' });
    }

    const user = rows[0];

    // Passwortüberprüfung mit bcrypt
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Ungültige Anmeldeinformationen' });
    }

    // Anmeldung erfolgreich
    res.json({
      message: 'Anmeldung erfolgreich',
      role: user.role,
      userId: user.id,
    });
  } catch (error) {
    console.error('Fehler bei der Anmeldung:', error);
    res.status(500).json({ error: 'Interner Serverfehler' });
  }
});

// Get bookings for a specific training
app.get('/api/trainings/:id/bookings', async (req, res) => {
  const { id } = req.params; // Training ID from the URL
  try {
    const [rows] = await pool.query(
      `SELECT 
         b.id AS booking_id, 
         b.training_id, 
         u.id AS user_id,
         u.email AS user_email,
         u.first_name,
         u.last_name,
         u.company,
         u.phone,
         s.titel AS training_title
       FROM bookings b
       JOIN users u ON b.user_id = u.id
       JOIN schulungen s ON b.training_id = s.id
       WHERE b.training_id = ?`,
      [id] // Use the ID from the URL params
    );    
    res.json(rows);
  } catch (error) {
    console.error('Error fetching bookings:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Search trainings
app.get('/api/trainings/search', async (req, res) => {
  try {
    const { query } = req.query;
    if (!query) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    // Clean and prepare search patterns
    const searchWords = query.toLowerCase().trim().split(/\s+/);
    
    // Handle date searches
    const cleanQuery = query.replace(/\./g, ''); // Remove dots
    const dateSearchPattern = `%${cleanQuery}%`;
    const dateParts = query.split('.');
    const dayPattern = dateParts[0] ? `%${dateParts[0]}%` : '%';
    const monthPattern = dateParts[1] ? `%${dateParts[1]}%` : '%';

    // Create a CTE for each search word
    const wordQueries = searchWords.map((word, index) => `
      SELECT DISTINCT s.id
      FROM schulungen s
      LEFT JOIN dozenten d ON s.dozent_id = d.id
      LEFT JOIN schulung_sessions ss ON s.id = ss.schulung_id
      WHERE 
        LOWER(s.titel) LIKE ? OR
        LOWER(s.beschreibung) LIKE ? OR
        LOWER(s.ort) LIKE ? OR
        LOWER(d.vorname) LIKE ? OR
        LOWER(d.nachname) LIKE ? OR
        LOWER(d.email) LIKE ? OR
        LOWER(CONCAT(d.vorname, ' ', d.nachname)) LIKE ? OR
        LOWER(CONCAT(d.nachname, ' ', d.vorname)) LIKE ? OR
        DATE_FORMAT(ss.datum, '%d') LIKE ? OR
        DATE_FORMAT(ss.datum, '%m') LIKE ? OR
        DATE_FORMAT(ss.datum, '%Y') LIKE ? OR
        DATE_FORMAT(ss.datum, '%d.%m.%Y') LIKE ? OR
        CAST(s.max_teilnehmer AS CHAR) LIKE ?
    `).join(' INTERSECT ');

    const searchQuery = `
      WITH matching_ids AS (${wordQueries})
      SELECT 
        s.*,
        d.vorname as dozent_vorname,
        d.nachname as dozent_nachname,
        d.email as dozent_email,
        (SELECT COUNT(*) FROM bookings b WHERE b.training_id = s.id) as booked_count,
        GROUP_CONCAT(ss.datum ORDER BY ss.datum) as dates,
        MIN(ss.datum) as start_date,
        MAX(ss.datum) as end_date,
        s.titel as training_name
      FROM matching_ids m
      JOIN schulungen s ON s.id = m.id
      LEFT JOIN dozenten d ON s.dozent_id = d.id
      LEFT JOIN schulung_sessions ss ON s.id = ss.schulung_id
      GROUP BY s.id
      ORDER BY s.gesamt_startdatum ASC
    `;

    // Create parameters array for all search words
    const params = searchWords.flatMap(word => {
      const pattern = `%${word}%`;
      return [
        pattern, // titel
        pattern, // beschreibung
        pattern, // ort
        pattern, // vorname
        pattern, // nachname
        pattern, // email
        pattern, // full name (firstname lastname)
        pattern, // full name (lastname firstname)
        pattern, // day
        pattern, // month
        pattern, // year
        pattern, // full date
        pattern  // max_teilnehmer
      ];
    });

    const [trainings] = await pool.execute(searchQuery, params);

    // Process dates for each training
    const processedTrainings = trainings.map(training => ({
      ...training,
      dates: training.dates ? training.dates.split(',') : [],
      is_multi_day: training.dates ? training.dates.split(',').length > 1 : false
    }));

    res.json(processedTrainings);
  } catch (error) {
    console.error('Error in search endpoint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a new booking
app.post('/api/bookings', async (req, res) => {
  const { user_id, training_id, send_email } = req.body;

  if (!user_id || !training_id) {
    return res.status(400).json({ error: 'user_id und training_id sind erforderlich' });
  }

  const connection = await pool.getConnection();

  try {
    // Check if user has already booked this training
    const [existingBooking] = await connection.query(
      'SELECT * FROM bookings WHERE user_id = ? AND training_id = ?',
      [user_id, training_id]
    );

    if (existingBooking.length > 0) {
      return res.status(400).json({ error: 'Sie haben dieses Training bereits gebucht' });
    }

    // Check if there are available spots
    const [[{ booked_count }]] = await connection.query(
      'SELECT COUNT(*) AS booked_count FROM bookings WHERE training_id = ?',
      [training_id]
    );

    const [[{ max_teilnehmer }]] = await connection.query(
      'SELECT max_teilnehmer FROM schulungen WHERE id = ?',
      [training_id]
    );

    if (booked_count >= max_teilnehmer) {
      return res.status(400).json({ error: 'Keine freien Plätze mehr verfügbar' });
    }

    // Get user's email and training details only if email should be sent
    let userEmail;
    let training;

    if (send_email) {
      // Get user's email from the database
      const [userRows] = await connection.query(
        'SELECT email FROM users WHERE id = ?',
        [user_id]
      );

      if (userRows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }

      userEmail = userRows[0].email;

      // Get training details
      const [trainingDetails] = await connection.query(
        `SELECT 
          s.*,
          d.vorname as dozent_vorname,
          d.nachname as dozent_nachname,
          d.email as dozent_email
        FROM schulungen s
        LEFT JOIN dozenten d ON s.dozent_id = d.id
        WHERE s.id = ?`,
        [training_id]
      );

      if (trainingDetails.length === 0) {
        return res.status(404).json({ error: 'Training not found' });
      }

      training = trainingDetails[0];
    }

    // Insert booking
    await connection.query(
      'INSERT INTO bookings (user_id, training_id) VALUES (?, ?)',
      [user_id, training_id]
    );

    // Send confirmation email if requested
    if (send_email && userEmail && training) {
      // Format dates for email
      let formattedDates = 'Keine Termine verfügbar';
      try {
        if (training.gesamt_startdatum && training.gesamt_enddatum) {
          const startDate = new Date(training.gesamt_startdatum);
          const endDate = new Date(training.gesamt_enddatum);
          
          const formatDate = (date) => {
            return date.toLocaleDateString('de-DE', {
              day: '2-digit',
              month: '2-digit',
              year: 'numeric'
            });
          };

          if (training.gesamt_startdatum === training.gesamt_enddatum) {
            formattedDates = formatDate(startDate);
          } else {
            formattedDates = `${formatDate(startDate)} - ${formatDate(endDate)}`;
          }

          // Add time blocks if available
          if (training.time_blocks) {
            const timeBlocks = JSON.parse(training.time_blocks);
            const formattedBlocks = timeBlocks.map(block => 
              `${block.start} - ${block.end} Uhr`
            ).join('<br>');
            if (formattedBlocks) {
              formattedDates += '<br>Zeitblöcke:<br>' + formattedBlocks;
            }
          }
        }
      } catch (e) {
        console.error('Error formatting dates:', e);
        formattedDates = 'Termine nicht verfügbar';
      }

      const mailOptions = {
        from: process.env.EMAIL_USER,
        to: userEmail,
        subject: `Buchungsbestätigung: ${training.titel}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h1 style="color: #2196F3;">Buchungsbestätigung</h1>
            <p>Sehr geehrte/r Teilnehmer/in,</p>
            
            <p>vielen Dank für Ihre Buchung. Hiermit bestätigen wir Ihre Anmeldung zu folgendem Training:</p>
            
            <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
              <h2 style="color: #1976D2; margin-top: 0;">${training.titel}</h2>
              <p><strong>Beschreibung:</strong><br>${training.beschreibung || 'Keine Beschreibung verfügbar'}</p>
              <p><strong>Dozent:</strong> ${training.dozent_vorname || ''} ${training.dozent_nachname || 'Nicht angegeben'}</p>
              <p><strong>Ort:</strong> ${training.ort || 'Nicht angegeben'}</p>
              <p><strong>Termine:</strong><br>${formattedDates}</p>
              <p><strong>Maximale Teilnehmerzahl:</strong> ${training.max_teilnehmer || 'Nicht angegeben'}</p>
            </div>

            <h3 style="color: #1976D2;">Wichtige Informationen:</h3>
            <ul style="list-style-type: none; padding-left: 0;">
              <li style="margin-bottom: 10px;">✓ Bitte erscheinen Sie 15 Minuten früher zu den Terminen</li>
              ${training.dozent_email ? 
                `<li style="margin-bottom: 10px;">✓ Bei Verhinderung informieren Sie bitte den Dozenten: ${training.dozent_email}</li>` 
                : ''}
              <li style="margin-bottom: 10px;">✓ Bringen Sie bei Bedarf Ihre eigenen Materialien mit</li>
            </ul>

            <p style="margin-top: 30px;">Bei Fragen stehen wir Ihnen gerne zur Verfügung.</p>
            
            <p>Mit freundlichen Grüßen<br>
            Ihr Trainings-Team</p>
            
            <div style="border-top: 2px solid #2196F3; margin-top: 30px; padding-top: 20px; font-size: 12px; color: #666;">
              <p>Dies ist eine automatisch generierte E-Mail. Bitte antworten Sie nicht auf diese E-Mail.</p>
            </div>
          </div>
        `
      };

      transporter.sendMail(mailOptions, (emailError, info) => {
        if (emailError) {
          console.error('Error sending email:', emailError);
          // Still return success for booking even if email fails
          res.status(201).json({ message: 'Training booked successfully, but email notification failed' });
          return;
        }
        console.log('Email sent:', info.response);
        res.status(201).json({ message: 'Training booked successfully and notification email sent' });
      });
    } else {
      // If no email should be sent, just return success
      res.status(201).json({ message: 'Training booked successfully' });
    }

  } catch (error) {
    console.error('Detailed error in booking:', {
      message: error.message,
      stack: error.stack,
      sqlMessage: error.sqlMessage
    });
    res.status(500).json({ 
      error: 'Error in booking process',
      details: error.message 
    });
  } finally {
    connection.release();
  }
});

// Cancel a booking
app.delete('/api/bookings', async (req, res) => {
  const { user_id, training_id } = req.query; // Changed from req.body to req.query for DELETE request

  if (!user_id || !training_id) {
    return res.status(400).json({ error: 'user_id und training_id sind erforderlich' });
  }

  const connection = await pool.getConnection();
  try {
    // Check if the booking exists
    const [existingBooking] = await connection.query(
      'SELECT * FROM bookings WHERE user_id = ? AND training_id = ?',
      [user_id, training_id]
    );

    if (existingBooking.length === 0) {
      return res.status(404).json({ error: 'Buchung nicht gefunden' });
    }

    // Delete the booking
    const [result] = await connection.query(
      'DELETE FROM bookings WHERE user_id = ? AND training_id = ?',
      [user_id, training_id]
    );

    console.log('Booking deleted:', { user_id, training_id, affectedRows: result.affectedRows });

    res.json({ 
      message: 'Buchung erfolgreich storniert',
      affectedRows: result.affectedRows 
    });
  } catch (error) {
    console.error('Error canceling booking:', error);
    res.status(500).json({ error: 'Fehler beim Stornieren der Buchung' });
  } finally {
    connection.release();
  }
});

// Cancel a training booking
app.delete('/api/trainings/:trainingId/cancel/:userId', async (req, res) => {
  const { trainingId, userId } = req.params;

  try {
    const db = await pool.getConnection();
    const collection = db;

    const training = await collection.query('SELECT * FROM bookings WHERE training_id = ? AND user_id = ?', [trainingId, userId]);

    if (!training[0]) {
      return res.status(404).json({ error: 'Training not found' });
    }

    // Remove user from bookedBy array
    const result = await collection.query(
      'DELETE FROM bookings WHERE training_id = ? AND user_id = ?',
      [trainingId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(400).json({ error: 'User was not booked for this training' });
    }

    res.json({ message: 'Training cancelled successfully' });
  } catch (error) {
    console.error('Error cancelling training:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Dozenten Endpoints
app.get('/api/dozenten', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.query('SELECT * FROM dozenten');
    res.json(rows);
  } catch (error) {
    console.error('Error fetching lecturers:', error);
    res.status(500).json({ error: 'Error fetching lecturers' });
  } finally {
    connection.release();
  }
});

app.post('/api/dozenten', async (req, res) => {
  const { vorname, nachname, email } = req.body;
  
  // Validate required fields
  if (!vorname || !nachname || !email) {
    return res.status(400).json({ 
      error: 'Missing required fields',
      details: 'Vorname, Nachname, and Email are required'
    });
  }

  const connection = await pool.getConnection();
  
  try {
    console.log('Creating new dozent:', { vorname, nachname, email });

    // First, check if the table exists
    const [tables] = await connection.query(
      'SHOW TABLES LIKE ?',
      ['dozenten']
    );
    
    if (tables.length === 0) {
      console.log('Creating dozenten table');
      await connection.query(`
        CREATE TABLE IF NOT EXISTS dozenten (
          id INT AUTO_INCREMENT PRIMARY KEY,
          vorname VARCHAR(255) NOT NULL,
          nachname VARCHAR(255) NOT NULL,
          email VARCHAR(255) NOT NULL UNIQUE
        )
      `);
    }

    const [result] = await connection.query(
      'INSERT INTO dozenten (vorname, nachname, email) VALUES (?, ?, ?)',
      [vorname, nachname, email]
    );
    
    console.log('Insert result:', result);
    
    const [newDozent] = await connection.query(
      'SELECT * FROM dozenten WHERE id = ?',
      [result.insertId]
    );
    
    console.log('New dozent:', newDozent[0]);
    res.status(201).json(newDozent[0]);
  } catch (error) {
    console.error('Detailed error creating lecturer:', error);
    
    // Check for duplicate email
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({
        error: 'Duplicate email',
        details: 'A lecturer with this email already exists'
      });
    }
    
    res.status(500).json({ 
      error: 'Error creating lecturer',
      details: error.message,
      sqlMessage: error.sqlMessage,
      sqlState: error.sqlState
    });
  } finally {
    connection.release();
  }
});

// Get tags by partial name match
app.get('/api/tags/search', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const searchTerm = req.query.q || '';
    const [tags] = await connection.query(
      'SELECT * FROM tags WHERE name LIKE ? LIMIT 10',
      [`%${searchTerm}%`]
    );
    res.json(tags);
  } catch (error) {
    console.error('Error searching tags:', error);
    res.status(500).json({ message: 'Error searching tags', error: error.message });
  } finally {
    connection.release();
  }
});

// Get tags for a specific training
app.get('/api/trainings/:id/tags', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(`
      SELECT t.* 
      FROM tags t
      JOIN schulungen_tags st ON t.id = st.tag_id
      WHERE st.schulung_id = ?
    `, [req.params.id]);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

// Get all tags
app.get('/api/tags', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const [tags] = await connection.query('SELECT * FROM tags ORDER BY name ASC');
    res.json(tags);
  } catch (error) {
    console.error('Error fetching tags:', error);
    res.status(500).json({ message: 'Error fetching tags', error: error.message });
  } finally {
    connection.release();
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
