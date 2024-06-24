use rest;

-- Points Trigger
DELIMITER //

DROP TRIGGER IF EXISTS before_loyalty_update //
CREATE TRIGGER before_loyalty_update
BEFORE UPDATE ON customers
FOR EACH ROW
BEGIN
    DECLARE remaining_points INT;

    IF NEW.loyalty_points >= 500 THEN
        -- Insert the recommendation message
        INSERT INTO recommendation (message)
        VALUES (CONCAT('Email ', NEW.email, ' to offer a discount'));

        -- Subtract 500 points
        SET NEW.loyalty_points = NEW.loyalty_points - 500;
    END IF;
END //
DELIMITER ;

drop trigger if exists FULL_TOTAL ;

DELIMITER //

-- Full total (food + gratuity trigger)
CREATE TRIGGER FULL_TOTAL
BEFORE INSERT ON bill
FOR EACH ROW
BEGIN
    DECLARE calculated_gratuity DECIMAL(10, 2);
    DECLARE calculated_full_total DECIMAL(10, 2);

    -- Calculate the gratuity as 15% of the food_total
    SET calculated_gratuity = NEW.food_total * 0.15;

    -- Calculate the full total as the sum of food_total and gratuity
    SET calculated_full_total = NEW.food_total + calculated_gratuity;

    -- Set the gratuity and full_total fields in the new row
    SET NEW.gratuity = calculated_gratuity;
    SET NEW.full_total = calculated_full_total;
END //

DELIMITER ;

-- Anniversary discount trigger

drop trigger if exists anniversary_discount;

DELIMITER //

create trigger anniversary_discount
before insert on bill
for each row
begin
    declare v_customer_id int;
    declare v_joined_date date;
    declare v_current_date date;
    declare v_discount_rate float default 0.40;

    -- Get the customer_id from the order
    select customer_id into v_customer_id
    from orders
    where order_id = NEW.order_id;

    -- Get the joined_date of the customer
    select date_joined into v_joined_date
    from customers
    where customer_id = v_customer_id;

    -- Get the current date
    set v_current_date = curdate();

    -- Check if the current date matches the anniversary date
    if date_format(v_current_date, '%m-%d') = date_format(v_joined_date, '%m-%d') then
        -- Apply the discount
        set NEW.full_total = NEW.full_total * (1 - v_discount_rate);
    end if;
end //

DELIMITER ;
