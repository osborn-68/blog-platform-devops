const express = require('express');
const mysql = require('mysql2');
const app = express();
const PORT = 5000;

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'bloguser',
  password: process.env.DB_PASSWORD || 'blogpass',
  database: process.env.DB_NAME || 'blogdb'
});

app.get('/posts', (req, res) => {
  db.query('SELECT id, title, body FROM posts', (err, results) => {
    if (err) {
      // Fallback demo data if DB isn't reachable yet, so the UI still works
      return res.json([
        { id: 1, title: 'Welcome to the Blog', body: 'This is a placeholder post (DB not connected).' }
      ]);
    }
    res.json(results);
  });
});

app.get('/', (req, res) => res.send('Backend API is running'));

app.listen(PORT, () => console.log(`Backend listening on port ${PORT}`));
