import streamlit as st
import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Database connection function
def create_connection():
    connection = None
    try:
        connection = mysql.connector.connect(
            host=os.getenv("DB_HOST"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME")
        )
    except Error as e:
        st.error(f"Error while connecting to MySQL: {e}")
    return connection

# Execute query function
def execute_query(query, params=None):
    connection = create_connection()
    if connection is None:
        st.error("Failed to create connection.")
        return None
    
    cursor = connection.cursor()
    results = None
    try:
        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)
        if cursor.description:
            results = cursor.fetchall()
        connection.commit()
    except Error as e:
        st.error(f"Error: {e}")
    finally:
        cursor.close()
        connection.close()
    return results

# Main Streamlit app
def main():
    st.title("Restaurant Bill Calculator")

    # Seat a table
    st.header("Seat a Table")
    num_people = st.number_input("Number of People", min_value=1, step=1)
    split = st.selectbox("Split Order?", [0, 1])
    if st.button("Seat Table"):
        result = execute_query("CALL SIT_TABLE(%s, %s)", (num_people, split))
        if result is not None:
            st.success("Table has been seated")

    # Get seated tables
    seated_tables = execute_query("SELECT DISTINCT table_id FROM orders WHERE completed = 0")
    table_ids = [row[0] for row in seated_tables] if seated_tables else []

    if table_ids:
        selected_table_id = st.selectbox("Select Table ID", table_ids)

        # Get orders for the selected table
        orders = execute_query("SELECT order_id, employee_id FROM orders WHERE table_id = %s AND completed = 0", (selected_table_id,))
        order_ids = [row[0] for row in orders]
        employee_id = orders[0][1] if orders else None

        selected_order_id = st.selectbox("Select Order ID", order_ids)
        st.write(f"Employee ID: {employee_id}")

        # Add food to order
        st.header("Add Food to Order")
        food_items = execute_query("SELECT food_id, name FROM food WHERE available = 1")
        food_dict = {row[1]: row[0] for row in food_items}
        selected_food_items = st.multiselect("Select Food Items", options=food_dict.keys())
        quantities = [st.number_input(f"Quantity for {item}", min_value=1, step=1) for item in selected_food_items]
        special_requests = [st.text_input(f"Special Requests for {item}") for item in selected_food_items]

        if st.button("Add Food to Order"):
            for item, quantity, request in zip(selected_food_items, quantities, special_requests):
                execute_query("CALL orderfood(%s, %s, %s, %s)", (selected_order_id, food_dict[item], quantity, request))
            st.success("Food items added to the order")

        # Generate Bill
        st.header("Generate Bill")
        customer_id_input = st.text_input("Customer ID (optional)", help="Leave empty if no customer ID")
        payment_method = st.selectbox("Payment Method", ["Cash", "Credit Card"])
        cc_num = st.text_input("Credit Card Number") if payment_method == "Credit Card" else None

        if st.button("Generate Bill"):
            if customer_id_input.strip():
                customer_id = int(customer_id_input)
                execute_query("CALL paycheck(%s, %s, %s, %s)", (selected_order_id, customer_id, payment_method, cc_num))
            else:
                execute_query("CALL paycheck(%s, NULL, %s, %s)", (selected_order_id, payment_method, cc_num))
            st.success("Bill generated")

            # Display the itemized receipt
            bill_details = execute_query("SELECT f.name, od.quantity, f.price, (od.quantity * f.price) AS total FROM orderdetails od JOIN food f ON od.item_id = f.food_id WHERE od.order_id = %s", (selected_order_id,))
            total_amount = execute_query("SELECT full_total FROM bill WHERE order_id = %s", (selected_order_id,))[0][0]

            st.subheader("Itemized Receipt")
            for item in bill_details:
                st.write(f"{item[0]} (x{item[1]}): ${item[3]:.2f}")
            st.write(f"Total Amount (including gratuity): ${total_amount:.2f}")

if __name__ == "__main__":
    main()
