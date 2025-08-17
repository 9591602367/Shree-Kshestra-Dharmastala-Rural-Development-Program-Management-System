from flask import Flask, render_template, request, redirect, session
import pyodbc
from db_config import conn_str

app = Flask(__name__)
app.secret_key = 'your_secret_key_here'  # Required for using sessions

# Connect to SQL Server
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

@app.route('/')
def home():
    return redirect('/login')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username'].strip()
        password = request.form['password'].strip()

        cursor.execute("SELECT * FROM Head WHERE HID = ? AND Password = ?", (username, password))
        user = cursor.fetchone()

        if user:
            session['user'] = username
            return redirect('/dashboard')
        else:
            return "Invalid credentials!"
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect('/login')
    
    try:
        # Count total members
        cursor.execute("SELECT COUNT(*) FROM Member")
        member_count = cursor.fetchone()[0] or 0

        # Count total loans issued
        cursor.execute("SELECT sum(loan_amount) FROM Loan")
        loan_count = cursor.fetchone()[0] or 0

        # Sum total savings
        cursor.execute("SELECT SUM(saving_amount) FROM Savings")
        total_savings = cursor.fetchone()[0] or 0

        # Count total insurance holders from Suraksha table
        cursor.execute("SELECT COUNT(DISTINCT member_id) FROM Suraksha")
        insurance_holders = cursor.fetchone()[0] or 0

        # Calculate the percentage of members with insurance
        insurance_percentage = (insurance_holders / member_count * 100) if member_count > 0 else 0

    except Exception as e:
        print("Error:", e)
        member_count, loan_count, total_savings, insurance_holders, insurance_percentage = "Error", "Error", "Error", "Error", "Error"

    return render_template('dashboard.html', 
                           member_count=member_count, 
                           loan_count=loan_count, 
                           total_savings=total_savings, 
                           insurance_holders=insurance_holders,
                           insurance_percentage=insurance_percentage)




@app.route('/add_group', methods=['GET', 'POST'])
def add_group():
    if 'user' not in session:
        return redirect('/login')
    
    if request.method == 'POST':
        group_id = request.form['group_id']
        group_name = request.form['group_name']

        try:
            cursor.execute("INSERT INTO Groups (Group_id, Group_name) VALUES (?, ?)", (group_id, group_name))
            conn.commit()
            return "Group added successfully!"
        except pyodbc.IntegrityError as e:
            return "Error: " + str(e)
    
    return render_template('add_group.html')

@app.route('/add_member', methods=['GET', 'POST'])
def add_member():
    if 'user' not in session:
        return redirect('/login')
    if request.method == 'POST':
        member_id = request.form['member_id']
        mname = request.form['mname']
        group_id = request.form['group_id']
        phone_no = request.form['phone_no']
        address = request.form['address']
        age = request.form['age']
        gender = request.form['gender']

        try:
            cursor.execute("""
                INSERT INTO Member (Member_ID, MName, Group_id, Phone_no, Address, Age, Gender)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (member_id, mname, group_id, phone_no, address, age, gender))
            conn.commit()
            return "Member added successfully!"
        except Exception as e:
            return "Error: " + str(e)

    return render_template('add_member.html')

@app.route('/members')
def view_members():
    if 'user' not in session:
        return redirect('/login')

    cursor.execute("SELECT * FROM Member")
    members = cursor.fetchall()
    return render_template('members.html', members=members)

@app.route('/groups')
def view_groups():
    if 'user' not in session:
        return redirect('/login')

    cursor.execute("SELECT * FROM Groups")
    groups = cursor.fetchall()
    return render_template('groups.html', groups=groups)

@app.route("/view_savings")
def view_savings():
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM Savings")
    savings = cursor.fetchall()
    return render_template("savings.html", savings=savings)


@app.route('/add_savings', methods=['GET', 'POST'])
def add_savings():
    if 'user' not in session:
        return redirect('/login')
    if request.method == 'POST':
        member_id = request.form['member_id']
        amount = float(request.form['amount'])

        try:
            cursor.execute("EXEC UpdateTotalSavings ?, ?", (member_id, amount))
            conn.commit()
            return "Savings updated successfully!"
        except pyodbc.IntegrityError as e:
            return "Error: " + str(e)
    return render_template('add_savings.html')

@app.route('/loan_settlement', methods=['GET', 'POST'])
def loan_settlement():
    if 'user' not in session:
        return redirect('/login')

    if request.method == 'POST':
        member_id = request.form.get('member_id')
        amount = request.form.get('amount', type=float)

        if not member_id or amount is None or amount <= 0:
            return "Invalid Member ID or loan amount."

        try:
            cursor = conn.cursor()  # Initialize cursor

            # Step 1: Update the installment
            cursor.execute("""
                UPDATE Loan 
                SET installement = ?
                WHERE member_id = ?
            """, (amount, member_id))

            # Step 2: Call the stored procedure to update amount_paid
            #cursor.execute("EXEC UpdateAmountPaid @member_id = ?", (member_id,))

            conn.commit()
            cursor.close()
            return "Loan settlement updated successfully!"

        except pyodbc.Error as e:
            return f"Database Error: {str(e)}"

    return render_template('loan_settlement.html')

@app.route('/add_loan', methods=['GET', 'POST'])
def add_loan():
    if 'user' not in session:
        return redirect('/login')
    
    if request.method == 'POST':
        member_id = request.form['member_id']
        loan_amount = float(request.form['loan_amount'])
        loan_term = int(request.form['loan_term'])
       

        # Check if loan already exists
        cursor.execute("SELECT * FROM Loan WHERE Member_ID = ?", (member_id,))
        existing_loan = cursor.fetchone()
        
        if existing_loan:
            return "Loan already exists for this member!"

        try:
            cursor.execute("""
                INSERT INTO Loan (Member_ID, loan_amount,loan_term)
                VALUES (?, ?, ?)
            """, (member_id, loan_amount,loan_term))
            conn.commit()
            return "Loan added successfully!"
        except Exception as e:
            return "Error: " + str(e)

    # Get members list for dropdown
    cursor.execute("SELECT Member_ID, MName FROM Member")
    members = cursor.fetchall()

    return render_template('add_loan.html', members=members)

@app.route('/add_suraksha', methods=['GET', 'POST'])
def add_suraksha():
    if 'user' not in session:
        return redirect('/login')
    
    if request.method == 'POST':
        member_id = request.form['member_id']
        suraksha_no = request.form['suraksha_no']
        group_id = request.form['group_id']
        amount_paid = float(request.form['amount_paid'])
        dependants = int(request.form['dependants'])

        try:
            cursor.execute("EXEC InsertSurakshaRecord ?, ?, ?, ?, ?", 
                           (member_id, suraksha_no, group_id, amount_paid, dependants))
            conn.commit()
            return "Suraksha record added successfully!"
        except Exception as e:
            return "Error: " + str(e)

    # Get dropdown options
    cursor.execute("SELECT Member_ID FROM Member")
    members = cursor.fetchall()
    cursor.execute("SELECT Group_id FROM Groups")
    groups = cursor.fetchall()

    return render_template('add_suraksha.html', members=members, groups=groups)

@app.route('/view_suraksha')
def view_suraksha():
    if 'user' not in session:
        return redirect('/login')
    
    cursor.execute("SELECT * FROM Suraksha")
    data = cursor.fetchall()
    return render_template('suraksha.html', data=data)


@app.route('/loans')
def view_loans():
    if 'user' not in session:
        return redirect('/login')
    
    cursor.execute("""
       SELECT *
       FROM Loan 
       JOIN Member  ON Loan.Member_ID = Member.Member_ID;
    """)
    loans = cursor.fetchall()
    
    return render_template('loans.html', loans=loans)


@app.route('/logout')
def logout():
    session.clear()
    return redirect('/login')

if __name__ == '__main__':
    app.run(debug=True)
