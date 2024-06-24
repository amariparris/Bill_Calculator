drop database if exists rest;
create database if not exists rest;
use rest;

-- Customer
drop table if exists customers;
create table customers (
    customer_id int primary key auto_increment,
    first_name varchar(255) not null,
    last_name varchar(255) not null,
    email varchar(255),
    loyalty_points int default 0,
    date_joined date default (current_date)
    -- Consider a trigger to send emails on anniversary membership if day = day w/ diff years add recc for discount.
);



-- Employee Roles
drop table if exists roles;
create table roles (
    role_id int primary key auto_increment,
    role_name varchar(20),
    description varchar(50)
);



-- Employees
drop table if exists employees;
create table employees (
    employee_id int primary key auto_increment,
    first_name varchar(255),
    last_name varchar(255),
    role_id int, -- foreign key
    email varchar(255),
    phone varchar(255),
    salary decimal(10, 2), -- hourly wage
    hire_date datetime default NOW(),
    foreign key (role_id) references roles(role_id)
);


-- Shifts
drop table if exists shifts;
create table shifts (
    shift_id int primary key auto_increment,
    shift_name varchar(20),
    start_time time,
    end_time time
);



-- Available Shifts. Join between
drop table if exists employeeshifts;
create table employeeshifts (
    employee_id int not null, -- FK
    shift_id int not null, -- FK
    primary key (employee_id, shift_id),
    foreign key (employee_id) references employees(employee_id),
    foreign key (shift_id) references shifts(shift_id)
);



-- Tables
drop table if exists tables;
create table tables (
    table_id int primary key auto_increment,
    capacity int, 
    status tinyint(1) default 0 -- occupied or empty. updated with trigger seat table makes 1 pay bill (if bill has table) makes it 0 for open add rec clear table
);



-- Categories
drop table if exists categories;
create table categories (
    category_id int primary key auto_increment,
    name varchar(50),
    description varchar(100)
);





-- Food
drop table if exists food;
create table food (
    food_id int primary key auto_increment,
    name varchar(50),
    description varchar(100),
    category_id int not null, -- FK
    price decimal(10, 2),
    available tinyint(1) default 1, -- 1 = available
    foreign key (category_id) references categories(category_id)
);



-- Orders 
drop table if exists orders; -- not generating these will create when we start adding orders
create table orders (
    order_id int primary key auto_increment,
    table_id int default 0 NOT NULL, -- can be no table if to-go order
    customer_id int default NULL,
    order_date datetime default NOW(),
    completed tinyint(1) default 0, -- 0 pending/ 1 completed. changed when bill paid w/ pay bill
    employee_id int,
    foreign key (table_id) references tables(table_id),
    foreign key (employee_id) references employees(employee_id),
    foreign key (customer_id) references customers(customer_id)
);


-- Order Details
drop table if exists orderdetails;
create table orderdetails (
    details_id int primary key auto_increment,
    order_id int not null,
    item_id int not null,
    quantity int,
    special_requests varchar(255),
    foreign key (order_id) references orders(order_id),
    foreign key (item_id) references food(food_id)
);




-- Bill
drop table if exists bill; -- if order_id exists here cannot add food item ORDER FOOD SP
create table bill (
    bill_id int primary key auto_increment,
    order_id int not null,
    food_total float not null,
    gratuity float default null,
    full_total float, -- filled with trigger after insert
    payment_method varchar(255),
    cc_num varchar(20), 
    date_paid datetime default NOW(),
    foreign key (order_id) references orders(order_id)
);


drop table if exists recommendation; -- add scheduled delete after a week
create table recommendation (
	message VARCHAR(255)
);

select * from customers;

-- STORED PROCEDURES
/* SIT TABLE (table_id, split) (AMARI)
		flips table to occupied
        checks num people fit at that table
        checks that table is open
        creates new order tied to that table
        if split 1 then create num_people order else create 1 order

    ORDER FOOD(order_id, item_id, quantity, requests) (YASEEN)
		adds entry to order details w/ inputs
        checks to make sure order is open by querying bill for order_id
        
	CREATE CHECK(table_id) (JACK)
		create a new blank order with new order ID on a table (optional)
        
	GET CHECK(order_id, discount)  (AMARI)
		displays all items ordered
        add sum at bottom (maybe rollup) w/ discount
        
	PAY CHECK(order_id, payment_method, cc_num) (YASEEN)
		add check to bill table
        switch table to open
        add rec to clear table
	
    AVAILABLE (shift_id) (JACK)
		display all available employees
*/


-- TRIGGERS/SCHEDULES
/*
	POINTS DISCOUNT (JACK)
		when member has 500 points add rec to email discount
	
    ANNIVERSARY DISCOUNT (optional) (YASEEN)
		add discount for anniversary
        scheduler every morning checks
	
    FULL TOTAL(bill_id) (AMARI)
		uses gratuity to calculate full total after insert
*/




