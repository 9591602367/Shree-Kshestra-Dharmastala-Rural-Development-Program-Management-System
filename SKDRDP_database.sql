-- Create and use the database
CREATE DATABASE db2;
USE db2;

-- Table: Director
CREATE TABLE Director (
    DID VARCHAR(10) NOT NULL,
    DName VARCHAR(20),
    CONSTRAINT pk31 PRIMARY KEY(DID)
);

-- Table: Supervisor
CREATE TABLE Supervisor (
    Supervisor_ID VARCHAR(10) NOT NULL,
    Supervisor_Name VARCHAR(20),
    DID VARCHAR(10) NOT NULL,
    CONSTRAINT pk32 PRIMARY KEY(Supervisor_ID),
    CONSTRAINT fk31 FOREIGN KEY(DID) REFERENCES Director(DID)
);

-- Table: Head
CREATE TABLE Head (
    HID VARCHAR(10) NOT NULL,
    HName VARCHAR(20),
    Supervisor_ID VARCHAR(10) NOT NULL,
    CONSTRAINT pk33 PRIMARY KEY(HID),
    CONSTRAINT fk32 FOREIGN KEY(Supervisor_ID) REFERENCES Supervisor(Supervisor_ID)
);


-- Table: Groups (renamed from Group1 for clarity)
CREATE TABLE Groups (
    Group_id VARCHAR(10) NOT NULL,
    Group_name VARCHAR(20),
    Group_Head VARCHAR(10),
    CONSTRAINT pk36 PRIMARY KEY(Group_id),
    CONSTRAINT fk35 FOREIGN KEY(Group_Head) REFERENCES Head(HID)
);

-- Table: Member
CREATE TABLE Member (
    Member_ID VARCHAR(10) NOT NULL,
    MName VARCHAR(50),
    Group_id VARCHAR(10),
    Phone_no VARCHAR(15),
    Address VARCHAR(30),
    Age INT,
    Gender CHAR(1),
    CONSTRAINT pk34 PRIMARY KEY(Member_ID),
    CONSTRAINT fk33 FOREIGN KEY(Group_id) REFERENCES Groups(Group_id)
);

-- Table: Savings
CREATE TABLE Savings (
    Member_ID VARCHAR(10) NOT NULL,
    saving_amount REAL,
    savings_per_week REAL,
    CONSTRAINT pk35 PRIMARY KEY(Member_ID),
    CONSTRAINT fk34 FOREIGN KEY(Member_ID) REFERENCES Member(Member_ID)
);

-- Table: Loan
CREATE TABLE Loan (
    Member_ID VARCHAR(10) NOT NULL,
    loan_amount REAL,
    EWI REAL,
    amount_paid REAL,
    amount_remaining AS (loan_amount - amount_paid),
    CONSTRAINT pk39 PRIMARY KEY(Member_ID),
    CONSTRAINT fk39 FOREIGN KEY(Member_ID) REFERENCES Member(Member_ID)
);
drop table Loan
CREATE TABLE Loan (
    member_id VARCHAR(10),
    loan_amount REAL NOT NULL,
    final_settlement_amount AS (loan_amount * 0.11 + loan_amount) PERSISTED, -- Auto-calculated final settlement amount
    loan_term INT NOT NULL, -- Number of months
    installement REAL, -- Fixed spelling
    ewi AS ((loan_amount * 0.11) + loan_amount) / loan_term PERSISTED, -- Auto-calculated EMI
    amount_paid real default 0.0, -- Regular column, cannot reference itself
    amount_remaining AS ((loan_amount * 0.11) + loan_amount - (amount_paid + installement)) PERSISTED, -- Correct formula to avoid referencing computed column
    CONSTRAINT pk68 PRIMARY KEY (member_id),
    CONSTRAINT fk69 FOREIGN KEY (member_id) REFERENCES Member(member_id)
);
select * from loan

CREATE PROCEDURE UpdateAmountPaid1
    @member_id VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Loan
    SET amount_paid = amount_paid + installment
    WHERE member_id = @member_id;
END;

CREATE TRIGGER trg_UpdateAmountPaid
ON Loan
after UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE L
    SET L.amount_paid = L.amount_paid + I.installement
    FROM Loan L
    INNER JOIN inserted I ON L.member_id = I.member_id
    WHERE I.installement IS NOT NULL;
END;

-- Table: Suraksha
CREATE TABLE Suraksha (
    Member_ID VARCHAR(10),
    Suraksha_No VARCHAR(10) NOT NULL,
    Group_id VARCHAR(10),
    Amount_Paid REAL,
    No_Of_Dependants INT,
    coverage_limit AS (No_Of_Dependants * 20000),
    start_date DATE,
    end_date DATE,
    CONSTRAINT pk37 PRIMARY KEY(Suraksha_No, Member_ID),
    CONSTRAINT fk36 FOREIGN KEY(Member_ID) REFERENCES Member(Member_ID),
    CONSTRAINT fk37 FOREIGN KEY(Group_Id) REFERENCES Groups(Group_id)
);

-- Table: Dependant
CREATE TABLE Dependant (
    Member_ID VARCHAR(10) NOT NULL,
    DName VARCHAR(20),
    Relation VARCHAR(20),
    CONSTRAINT pk38 PRIMARY KEY(Member_ID, DName),
    CONSTRAINT fk38 FOREIGN KEY(Member_ID) REFERENCES Member(Member_ID)
);

-- Sample SELECTs (for testing)
SELECT * FROM Director;
SELECT * FROM Supervisor;
SELECT * FROM Head;
SELECT * FROM Member;
SELECT * FROM Groups;
SELECT * FROM Suraksha;
SELECT * FROM Loan;
SELECT * FROM Savings;
SELECT * FROM Dependant;

-- Stored Procedure: UpdateTotalSavings
CREATE PROCEDURE UpdateTotalSavings
    @Member_ID VARCHAR(10),
    @Savings_Per_Week REAL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Savings WHERE Member_ID = @Member_ID)
    BEGIN
        UPDATE Savings
        SET saving_amount = saving_amount + @Savings_Per_Week,
            savings_per_week = @Savings_Per_Week
        WHERE Member_ID = @Member_ID;
    END
    ELSE
    BEGIN
        INSERT INTO Savings (Member_ID, saving_amount, savings_per_week)
        VALUES (@Member_ID, @Savings_Per_Week, @Savings_Per_Week);
    END
END;

-- Sample procedure execution
-- EXEC UpdateTotalSavings 'M001', 500;

-- Stored Procedure: Insert into Suraksha
CREATE PROCEDURE InsertSurakshaRecord
    @Member_ID VARCHAR(10),
    @Suraksha_No VARCHAR(10),
    @Group_id VARCHAR(10),
    @Amount_Paid REAL,
    @No_Of_Dependants INT
AS
BEGIN
    INSERT INTO Suraksha (Member_ID, Suraksha_No, Group_id, Amount_Paid, No_Of_Dependants, start_date)
    VALUES (@Member_ID, @Suraksha_No, @Group_id, @Amount_Paid, @No_Of_Dependants, GETDATE());
END;

-- Trigger: Set Suraksha End Date Automatically
CREATE TRIGGER trg_SetEndDate
ON Suraksha
AFTER INSERT
AS
BEGIN
    UPDATE S
    SET 
        start_date = ISNULL(I.start_date, GETDATE()),
        end_date = DATEADD(YEAR, 1, ISNULL(I.start_date, GETDATE()))
    FROM Suraksha S
    INNER JOIN inserted I
        ON S.Member_ID = I.Member_ID AND S.Suraksha_No = I.Suraksha_No;
END;

ALTER TABLE Head ADD Password VARCHAR(255);


INSERT INTO Director (DID, DName)
VALUES
('D001', 'Dr. Arjun Singh'),
('D002', 'Ms. Kavita Nair');

INSERT INTO Supervisor (Supervisor_ID, Supervisor_Name, DID)
VALUES
('S001', 'Anita Rao', 'D001'),
('S002', 'Rahul Mehta', 'D002');

INSERT INTO Head (HID, HName, Supervisor_ID)
VALUES
('H001', 'Priya Sharma', 'S001'),
('H002', 'Ravi Kumar', 'S002');

UPDATE Head
SET Password = 'priya123'
WHERE HID = 'H001';

UPDATE Head
SET Password = 'ravi456'
WHERE HID = 'H002';

ALTER TABLE Member
ALTER COLUMN Gender VARCHAR(10);

select count(*)as NO_of_members
from Member
select loan_amount

SELECT sum(final_settlement_amount) FROM Loan


