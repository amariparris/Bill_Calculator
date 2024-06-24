use rest;

DROP PROCEDURE IF EXISTS createCheck;

DELIMITER //

CREATE PROCEDURE createCheck(
    IN p_table_id INT,
    IN p_employee_id INT
)
BEGIN
    -- Variable declarations
    DECLARE v_table_exists INT;
    DECLARE v_employee_exists INT;

    -- Error handler declaration
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid table_id or employee_id';
    END;

    -- Start transaction
    START TRANSACTION;

    -- Check if table_id exists
    SELECT COUNT(*) INTO v_table_exists FROM tables WHERE table_id = p_table_id;

    -- Check if employee_id exists
    SELECT COUNT(*) INTO v_employee_exists FROM employees WHERE employee_id = p_employee_id;

    -- Check if both table_id and employee_id are valid
    IF v_table_exists = 1 AND v_employee_exists = 1 THEN
        -- Insert into orders with DEFAULT for customer_id
        INSERT INTO orders (table_id, order_date, completed, employee_id)
        VALUES (p_table_id, NOW(), 0, p_employee_id);
    ELSE
        -- Signal error if invalid table_id or employee_id
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid table_id or employee_id';
    END IF;

    -- Commit transaction
    COMMIT;
END //

DELIMITER ;

-- available shifts
DROP PROCEDURE IF EXISTS employeeAvailable;
DELIMITER //
CREATE PROCEDURE employeeAvailable
    (
        shift_id_var INT
    )
BEGIN 
	IF shift_id_var IN (SELECT shift_id FROM shifts) THEN
		SELECT e.first_name, e.last_name, e.email
		FROM employeeshifts es
		JOIN employees e ON (e.employee_id = es.employee_id)
		WHERE shift_id = shift_id_var;
	ELSE
        SIGNAL SQLSTATE 'HY000'
        SET MESSAGE_TEXT = 'Invalid Shift ID';
    END IF;
END //

DROP PROCEDURE IF EXISTS SIT_TABLE;

DELIMITER //

CREATE PROCEDURE SIT_TABLE(IN num_people INT, IN split INT)
BEGIN
    DECLARE table_found INT;
    DECLARE waiter_id INT;
    DECLARE done INT DEFAULT 0;
    DECLARE current_datetime DATETIME;
    DECLARE current_day VARCHAR(10);

    -- Get the current datetime and day of the week
    SET current_datetime = NOW();
    SET current_day = DAYNAME(CURDATE());

    -- Find an available table that can accommodate the party
    SELECT table_id INTO table_found
    FROM tables
    WHERE status = 0 AND capacity >= num_people
    LIMIT 1;

    IF table_found IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No suitable table available';
    ELSE
        -- Mark the table as occupied
        UPDATE tables
        SET status = 1
        WHERE table_id = table_found;

        -- Find an available waiter for the current shift
        SELECT e.employee_id INTO waiter_id
        FROM employees e
        JOIN roles r ON e.role_id = r.role_id
        JOIN employeeshifts es ON e.employee_id = es.employee_id
        JOIN shifts s ON es.shift_id = s.shift_id
        WHERE r.role_name = 'Server'
          AND s.start_time <= TIME(current_datetime)
          AND s.end_time >= TIME(current_datetime)
        LIMIT 1;

        IF waiter_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available waiter';
        ELSE
            -- Insert orders
            WHILE NOT done DO
                INSERT INTO orders (table_id, employee_id)
                VALUES (table_found, waiter_id);

                IF split = 1 THEN
                    SET num_people = num_people - 1;
                    IF num_people = 0 THEN
                        SET done = 1;
                    END IF;
                ELSE
                    SET done = 1;
                END IF;
            END WHILE;
        END IF;
 
    END IF;
END //

DELIMITER ;

drop procedure if exists GET_CHECK;

DELIMITER //

CREATE PROCEDURE GET_CHECK(IN order_id INT, IN discount DECIMAL(5, 2))
BEGIN
    DECLARE total DECIMAL(10, 2);
    DECLARE discounted_total DECIMAL(10, 2);

    -- Calculate the total price of the order
    SELECT SUM(f.price * od.quantity) INTO total
    FROM orderdetails od
    JOIN food f ON od.item_id = f.food_id
    WHERE od.order_id = order_id;

    IF total IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid order ID';
    END IF;

    -- Apply discount if provided
    IF discount IS NOT NULL THEN
        SET discounted_total = total - (total * (discount / 100));
    ELSE
        SET discounted_total = total;
    END IF;

    -- Display the items and total
    SELECT f.name, f.price, od.quantity, (f.price * od.quantity) AS item_total
    FROM orderdetails od
    JOIN food f ON od.item_id = f.food_id
    WHERE od.order_id = order_id;

    SELECT discounted_total AS total;
END //

DELIMITER ;

drop procedure if exists orderfood;

DELIMITER //

create procedure orderfood(
    in p_order_id int,
    in p_item_id int,
    in p_quantity int,
    in p_requests varchar(255)
)
begin
    declare v_order_open int;

    -- Check if order is open by querying bill.
    select count(*)
    into v_order_open
    from bill
    where order_id = p_order_id;

    if v_order_open = 0 then -- no matches exist.
        -- if  order is open insert into orderdetails
        insert into orderdetails (order_id, item_id, quantity, special_requests)
        values (p_order_id, p_item_id, p_quantity, p_requests);
    else
        -- if order is closed signal an error
        signal sqlstate '45000'
        set message_text = 'Order is closed and cannot accept new items.';
    end if;
end //

DELIMITER ;

drop procedure if exists paycheck;
DELIMITER //

create procedure paycheck(
    in p_order_id int,
    in p_customer_id int, 
    in p_payment_method varchar(255),
    in p_cc_num VARCHAR(20)
)
begin
    declare v_food_total float;
    declare v_gratuity float;
    declare v_full_total float;

    -- Calculate the food total for the order
    select sum(f.price * od.quantity)
    into v_food_total
    from orderdetails od
    join food f on od.item_id = f.food_id
    where od.order_id = p_order_id;

    -- Optionally, you can set a fixed gratuity rate, e.g., 15%
    set v_gratuity = v_food_total * 0.15;
    set v_full_total = v_food_total + v_gratuity;

    -- Insert into bill table
    insert into bill (order_id, food_total, gratuity, full_total, payment_method, cc_num)
    values (p_order_id, v_food_total, v_gratuity, v_full_total, p_payment_method, p_cc_num);

    -- Update the order to completed
    update orders
    set completed = 1
    where order_id = p_order_id;

    -- Set the table status to open
    update tables
    set status = 0
    where table_id = (select table_id from orders where order_id = p_order_id);

    -- Add record to clear the table (this can be an entry in a log table or another action as needed)
    insert into recommendation (message)
    values (concat('Table ', (select table_id from orders where order_id = p_order_id), ' is now open and needs to be cleared.'));
end //

DELIMITER ;