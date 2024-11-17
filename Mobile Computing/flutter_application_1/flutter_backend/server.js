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
        GROUP_CONCAT(DISTINCT ss.datum ORDER BY ss.datum ASC) AS dates
      FROM bookings b
      JOIN schulungen s ON b.training_id = s.id
      LEFT JOIN schulung_sessions ss ON s.id = ss.schulung_id
      WHERE b.user_id = ?
      GROUP BY b.training_id
      `,
      [userId]
    );

    // Verarbeiten der Daten
    const userBookings = bookings.map(row => ({
      ...row,
      dates: row.dates ? row.dates.split(',') : [],
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
        s.gesamt_startdatum,
        s.gesamt_enddatum,
        GROUP_CONCAT(DISTINCT ss.datum ORDER BY ss.datum ASC) AS dates,
        COUNT(DISTINCT b.id) AS booked_count
      FROM
        schulungen s
      LEFT JOIN
        schulung_sessions ss ON s.id = ss.schulung_id
      LEFT JOIN
        bookings b ON s.id = b.training_id
      GROUP BY
        s.id
    `);

    const trainings = rows.map(row => ({
      ...row,
      dates: row.dates ? row.dates.split(',') : [],
    }));

    res.json(trainings);
  } catch (error) {
    console.error('Fehler beim Abrufen der Schulungen:', error);
    res.status(500).send({ message: 'Fehler beim Abrufen der Schulungen' });
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
  const { vorname, nachname, unternehmen, rolle, email, telefon, passwort } = req.body; // Weitere Eigenschaften können hinzugefügt werden
  try {
    // Insert the user into the database
    const hashedPassword = await bcrypt.hash(passwort, 10); // bcrypt for secure password storage

    const [result] = await pool.query(
      `INSERT INTO users (first_Name, last_Name, company, role, email, phone, password)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [vorname, nachname, unternehmen, rolle, email, telefon, hashedPassword] // Hash passwort for security
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



app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
