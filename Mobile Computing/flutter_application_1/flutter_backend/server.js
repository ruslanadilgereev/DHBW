const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs'); // Für Passwort-Hashing
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

// Test Route
app.get('/', (req, res) => {
  res.send('Backend Server is Running');
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
        COUNT(DISTINCT ss.datum) as session_count
      FROM bookings b
      JOIN schulungen s ON b.training_id = s.id
      LEFT JOIN dozenten d ON s.dozent_id = d.id
      LEFT JOIN schulung_sessions ss ON s.id = ss.schulung_id
      LEFT JOIN bookings b2 ON s.id = b2.training_id
      WHERE b.user_id = ?
      GROUP BY b.training_id
      ORDER BY s.titel ASC`,
      [userId]
    );

    // Process the dates and format
    const userBookings = bookings.map(row => ({
      ...row,
      dates: row.dates ? row.dates.split(',') : [],
      start_date: row.start_date ? row.start_date.toISOString().split('T')[0] : null,
      end_date: row.end_date ? row.end_date.toISOString().split('T')[0] : null,
      is_multi_day: row.session_count > 1
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
    const [rows] = await connection.query(`
      SELECT
        s.id,
        s.titel AS training_name,
        s.beschreibung,
        s.ort,
        s.max_teilnehmer,
        s.dozent_id,
        d.vorname AS dozent_vorname,
        d.nachname AS dozent_nachname,
        d.email AS dozent_email,
        GROUP_CONCAT(DISTINCT DATE_FORMAT(ss.datum, '%Y-%m-%d') ORDER BY ss.datum ASC) AS dates,
        COUNT(DISTINCT b.id) AS booked_count,
        MIN(ss.datum) as start_date,
        MAX(ss.datum) as end_date,
        COUNT(DISTINCT ss.datum) as session_count
      FROM
        schulungen s
      LEFT JOIN
        dozenten d ON s.dozent_id = d.id
      LEFT JOIN
        schulung_sessions ss ON s.id = ss.schulung_id
      LEFT JOIN
        bookings b ON s.id = b.training_id
      GROUP BY
        s.id
      ORDER BY
        start_date ASC
    `);

    // Process the dates
    const trainings = rows.map(row => ({
      ...row,
      dates: row.dates ? row.dates.split(',') : [],
      start_date: row.start_date ? row.start_date.toISOString().split('T')[0] : null,
      end_date: row.end_date ? row.end_date.toISOString().split('T')[0] : null,
      is_multi_day: row.session_count > 1
    }));

    res.json(trainings);
  } catch (error) {
    console.error('Error fetching trainings:', error);
    res.status(500).json({ error: 'Error fetching trainings' });
  } finally {
    connection.release();
  }
});

// Create a new training
app.post('/api/trainings', async (req, res) => {
  const { training_name, description, location, max_participants, lecturer_id, dates, pauses } = req.body;

  const connection = await pool.getConnection();

  try {
    // Beginne eine Transaktion
    await connection.beginTransaction();

    // Füge die Schulung hinzu
    const [result] = await connection.execute(
      'INSERT INTO schulungen (titel, beschreibung, ort, max_teilnehmer, dozent_id, gesamt_startdatum, gesamt_enddatum) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [training_name, description, location, max_participants, lecturer_id, dates[0], dates[dates.length - 1]]
    );

    const trainingId = result.insertId;

    // Füge die Trainingstage hinzu
    const sessionInserts = dates.map(date => [trainingId, date, '09:00:00', '17:00:00', 'normal', null]);
    await connection.query(
      'INSERT INTO schulung_sessions (schulung_id, datum, startzeit, endzeit, typ, bemerkung) VALUES ?',
      [sessionInserts]
    );

    // Füge die Pausen hinzu
    if (pauses && pauses.length > 0) {
      const pauseInserts = pauses.map(pause => [trainingId, pause.start, pause.end, 'Pausengrund']);
      await connection.query(
        'INSERT INTO schulung_pause (schulung_id, start_datum, end_datum, grund) VALUES ?',
        [pauseInserts]
      );
    }

    // Commit der Transaktion
    await connection.commit();
    res.status(201).send({ message: 'Schulung hinzugefügt' });
  } catch (error) {
    // Rollback bei Fehler
    await connection.rollback();
    console.error('Fehler beim Hinzufügen der Schulung:', error);
    res.status(500).send({ message: 'Fehler beim Hinzufügen der Schulung' });
  } finally {
    // Verbindung freigeben
    connection.release();
  }
});

// Update a training by ID
app.put('/api/trainings/:id', async (req, res) => {
  const { id } = req.params;
  const { date, training_name } = req.body;

  try {
    const [result] = await pool.query(
      'UPDATE schulungen SET gesamt_startdatum = ?, titel = ? WHERE id = ?',
      [date, training_name, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Training not found' });
    }

    res.json({ message: 'Training updated' });
  } catch (error) {
    console.error('Error updating training:', error);
    res.status(500).json({ error: 'Internal Server Error' });
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
  const { user_id, training_id } = req.body;

  if (!user_id || !training_id) {
    return res.status(400).json({ error: 'user_id und training_id sind erforderlich' });
  }

  const connection = await pool.getConnection();

  try {
    // Überprüfen, ob der Nutzer die Schulung bereits gebucht hat
    const [existingBooking] = await connection.query(
      'SELECT * FROM bookings WHERE user_id = ? AND training_id = ?',
      [user_id, training_id]
    );

    if (existingBooking.length > 0) {
      return res.status(400).json({ error: 'Sie haben dieses Training bereits gebucht' });
    }

    // Überprüfen, ob es noch freie Plätze gibt
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

    // Buchung einfügen
    await connection.query(
      'INSERT INTO bookings (user_id, training_id) VALUES (?, ?)',
      [user_id, training_id]
    );

    res.status(201).json({ message: 'Buchung erfolgreich' });
  } catch (error) {
    console.error('Fehler bei der Buchung:', error);
    res.status(500).json({ error: 'Fehler bei der Buchung' });
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

// Start the server
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
