const http = require('http');
const fs = require('fs');

http.get('http://127.0.0.1:4000/api/v1/orders', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      console.log('Orders found:', json.orders ? json.orders.length : 0);
      if (json.orders && json.orders.length > 0) {
        const ord = json.orders[0];
        console.log('Order ID:', ord.id, 'Total:', ord.finalAmount, 'Profit:', ord.profit);
        
        // Test PDF generation for Template 1, 2, 3
        ['1', '2', '3'].forEach(tpl => {
          http.get(`http://127.0.0.1:4000/api/v1/orders/${ord.id}/invoice-pdf?template=${tpl}`, (pdfRes) => {
            console.log(`Invoice T${tpl} statusCode:`, pdfRes.statusCode, 'Length:', pdfRes.headers['content-length']);
          });
        });
      }
    } catch (e) {
      console.error('Error parsing:', e.message);
    }
  });
}).on('error', e => console.error('Request error:', e.message));
