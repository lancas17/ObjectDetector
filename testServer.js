// install express with: npm install express
// run with: node testServer.js

const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
    const input = req.query.input;
    if (input) {
        console.log('Received input:', input);
        res.send('Data received by the server.');
    } else {
        res.send('Hello World!');
    }
});

app.listen(port, () => {
    console.log(`Server listening at http://localhost:${port}`);
});
