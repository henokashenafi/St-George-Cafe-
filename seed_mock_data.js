/**
 * POS Mock Data Seeder
 * Use this script in the browser console to seed 15 days of mock data.
 */

(function seedPOSData() {
    console.log("Starting POS Data Seeding...");

    const STORAGE_KEY = 'pos_web_storage';
    const data = JSON.parse(localStorage.getItem(STORAGE_KEY)) || {
        categories: [],
        products: [],
        tables: [],
        table_zones: [],
        orders: [],
        order_items: [],
        waiters: [],
        users: [],
        app_settings: [],
        pos_charges: [],
        audit_logs: [],
        shifts: [],
        z_reports: []
    };

    // --- Configuration ---
    const DAYS_TO_MOCK = 15;
    const ORDERS_PER_DAY = 20;
    
    // Ensure we have basic data if empty
    if (data.products.length === 0) {
        data.categories = [
            { id: 1, name: 'Coffee' },
            { id: 2, name: 'Tea' },
            { id: 3, name: 'Pastries' },
            { id: 4, name: 'Soft Drinks' }
        ];
        data.products = [
            { id: 1, category_id: 1, name: 'Macchiato', price: 35.0 },
            { id: 2, category_id: 1, name: 'Black Coffee', price: 25.0 },
            { id: 3, category_id: 2, name: 'Black Tea', price: 15.0 },
            { id: 4, category_id: 3, name: 'Croissant', price: 55.0 },
            { id: 5, category_id: 4, name: 'Coca Cola', price: 30.0 }
        ];
    }
    
    if (data.tables.length === 0) {
        data.tables = Array.from({ length: 10 }, (_, i) => ({
            id: i + 1,
            name: `Table ${i + 1}`,
            status: 'available',
            zone_id: null
        }));
    }
    
    if (data.waiters.length === 0) {
        data.waiters = [{ id: 1, name: 'Default Waiter', code: 'W001' }];
    }

    const startId = (data.orders.length > 0) ? Math.max(...data.orders.map(o => o.id)) + 1 : 1;
    let currentOrderId = startId;
    let currentItemId = (data.order_items.length > 0) ? Math.max(...data.order_items.map(i => i.id)) + 1 : 1;

    const now = new Date();
    
    for (let d = 0; d < DAYS_TO_MOCK; d++) {
        const date = new Date();
        date.setDate(now.getDate() - d);
        
        console.log(`Generating data for ${date.toDateString()}...`);

        for (let o = 0; o < ORDERS_PER_DAY; o++) {
            // Random time during the day (8 AM to 10 PM)
            const orderTime = new Date(date);
            orderTime.setHours(8 + Math.floor(Math.random() * 14), Math.floor(Math.random() * 60));

            const table = data.tables[Math.floor(Math.random() * data.tables.length)];
            const waiter = data.waiters[0];
            
            // Random items (1 to 5)
            const itemCount = 1 + Math.floor(Math.random() * 5);
            let subtotal = 0;
            const items = [];

            for (let i = 0; i < itemCount; i++) {
                const product = data.products[Math.floor(Math.random() * data.products.length)];
                const qty = 1 + Math.floor(Math.random() * 3);
                const itemTotal = product.price * qty;
                
                const orderItem = {
                    id: currentItemId++,
                    order_id: currentOrderId,
                    product_id: product.id,
                    product_name: product.name,
                    category_name: data.categories.find(c => c.id === product.category_id).name,
                    quantity: qty,
                    unit_price: product.price,
                    subtotal: itemTotal,
                    status: 'completed',
                    created_at: orderTime.toISOString()
                };
                
                data.order_items.push(orderItem);
                items.push(orderItem);
                subtotal += itemTotal;
            }

            const serviceCharge = subtotal * 0.05;
            const grandTotal = subtotal + serviceCharge;

            const order = {
                id: currentOrderId++,
                table_id: table.id,
                table_name: table.name,
                waiter_id: waiter.id,
                waiter_name: waiter.name,
                cashier_id: 1,
                cashier_name: 'Director',
                total_amount: subtotal,
                service_charge: serviceCharge,
                discount_amount: 0,
                grand_total: grandTotal,
                payment_method: Math.random() > 0.3 ? 'cash' : 'card',
                status: 'completed',
                created_at: orderTime.toISOString(),
                shift_id: null
            };

            data.orders.push(order);
        }
    }

    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    console.log(`Successfully seeded ${DAYS_TO_MOCK * ORDERS_PER_DAY} orders!`);
    console.log("Please refresh the page to see the new data.");
})();
