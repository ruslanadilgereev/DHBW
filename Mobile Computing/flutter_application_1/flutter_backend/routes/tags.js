const express = require('express');
const router = express.Router();
const mysql = require('mysql2');
const pool = require('../db');

// Create a new tag
router.post('/', async (req, res) => {
    try {
        const { name } = req.body;
        
        // Check if tag already exists
        const [existingTag] = await pool.promise().query(
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
        const [result] = await pool.promise().query(
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
    }
});

// Get tag by name
router.get('/byName/:name', async (req, res) => {
    try {
        const [tag] = await pool.promise().query(
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
    }
});

// Associate tags with training
router.post('/training-tags', async (req, res) => {
    try {
        const { trainingId, tagIds } = req.body;

        // Insert all tag associations
        const values = tagIds.map(tagId => [trainingId, tagId]);
        await pool.promise().query(
            'INSERT INTO training_tags (training_id, tag_id) VALUES ?',
            [values]
        );

        res.status(201).json({ message: 'Tags associated with training successfully' });
    } catch (error) {
        console.error('Error associating tags:', error);
        res.status(500).json({ message: 'Error associating tags', error: error.message });
    }
});

// Get tags for a training
router.get('/training/:trainingId', async (req, res) => {
    try {
        const [tags] = await pool.promise().query(
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
    }
});

module.exports = router;
