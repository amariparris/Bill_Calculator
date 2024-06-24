# Bill Calculator Streamlit App

This repository contains a Streamlit web application for a restaurant management system. The app provides functionality to manage table seating, order food, and generate itemized bills with gratuity calculation. Key features include:

- **Table Management**: Seat tables and assign orders to available waitstaff.
- **Order Management**: Add food items to orders with special requests.
- **Bill Generation**: Calculate and display itemized receipts, including gratuity.
- **Payment Processing**: Integrate with the database to finalize orders and process payments.

## How to Deploy Locally

1. **Clone the repository**:
   ```sh
   git clone https://github.com/yourusername/Bill_Calculator.git
   cd Bill_Calculator
   
2. Set up a virtual environment:
   ```sh
   python -m venv venv
   source venv/bin/activate  # On Windows use `venv\Scripts\activate`

4. Install the required packages:
   ```sh
   pip install -r requirements.txt

6. Create a .env file in the project directory with your database credentials:
   ```sh
   DB_HOST=your_host
   DB_USER=your_username
   DB_PASSWORD=your_password
   DB_NAME=your_database

7. Run the Streamlit app:
   ```sh
   streamlit run Bill_Calculator.py

The application is also be accessible at http://xxxx.
