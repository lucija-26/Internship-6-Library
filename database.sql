-- Country

CREATE TABLE Countries (
    countryId SERIAL PRIMARY KEY,
    name VARCHAR(100),
    population INT,
    avgSalary DECIMAL
)

-- Library

CREATE TABLE Libraries (
    libraryId SERIAL PRIMARY KEY,
    name VARCHAR(100),
    address VARCHAR(100),
    workingHours VARCHAR(100)
)

-- Books

CREATE TYPE genres AS ENUM ('school', 'artistic', 'scientific', 'biography', 'professional');

CREATE TABLE Books (
    bookId SERIAL PRIMARY KEY,
    title VARCHAR(100),
    dateOfPublication DATE,
    genre genres,
    numberOfPages INTEGER,
    price DECIMAL(10, 2)
)

-- Authors

CREATE TYPE genders AS ENUM ('male', 'female', 'other', 'unknown');

CREATE TABLE Authors (
    authorId SERIAL PRIMARY KEY,
    firstName VARCHAR(100),
    lastName VARCHAR(100),
    gender genders,
    birthDate DATE,
    countryId INT REFERENCES Countries(countryId)
)

-- Authorship

CREATE TYPE authorshipTypes AS ENUM('main', 'secondary');

CREATE TABLE Authorship (
    bookId INT REFERENCES Books(bookId),
    authorId INT REFERENCES Authors(authorId),
    authorshipType authorshipTypes,
    PRIMARY KEY (bookId, authorId)
)

-- Users

CREATE TABLE Users (
    userId SERIAL PRIMARY KEY,
    firstName VARCHAR(100),
    lastName VARCHAR(100),
    email VARCHAR(150),
    password VARCHAR(100)
)

-- Copies

CREATE TABLE Copies (
    copyId SERIAL PRIMARY KEY,
    bookId INT REFERENCES Books(bookId),
    libraryId INT REFERENCES Libraries(libraryId),
    isbn VARCHAR(50)
)

-- Loan

CREATE TABLE Loans (
    loanId SERIAL PRIMARY KEY,
    copyId INT REFERENCES Copies(copyId),
    userId INT REFERENCES Users(userId),
	loanDate DATE NOT NULL,
    dueDate DATE NOT NULL,
    extensionDays INT DEFAULT 0,
    returned BOOLEAN DEFAULT FALSE
)

-- Employees

CREATE TABLE Employees (
    employeeId SERIAL PRIMARY KEY,
    firstName VARCHAR(100),
    lastName VARCHAR(100),
    email VARCHAR(150),
    password VARCHAR(255),
    role VARCHAR(50),
	libraryId INT NOT NULL REFERENCES Libraries(libraryId),
    UNIQUE(libraryId)
)


-- Payments


-- book loan

CREATE OR REPLACE FUNCTION loanBook(p_copy_id INT, p_user_id INT, OUT result TEXT) AS $$
DECLARE
    dueDate DATE;
BEGIN
    IF (SELECT COUNT(*) FROM Loans WHERE userId = p_user_id AND returned = FALSE) >= 3 THEN
        result := 'The user already borrowed the max amount of books.';
        RETURN;
    END IF;
	
    INSERT INTO Loans(copy_id, user_id, due_date) VALUES (p_copy_id, p_user_id, CURRENT_DATE + 20) RETURNING dueDate INTO dueDate;

    result := 'Book loaned until ' || dueDate;
END;
$$ LANGUAGE plpgsql;

-- costs of delay

CREATE OR REPLACE FUNCTION calculateLateFee(p_loan_id INT) RETURNS DECIMAL AS $$
DECLARE
    days_late INT;
    late_fee DECIMAL;
BEGIN
    SELECT
        CASE
            WHEN CURRENT_DATE <= (due_date + extension_days) THEN 0
            ELSE (CURRENT_DATE - (due_date + extension_days))::INT
        END INTO days_late
    FROM Loans
    WHERE loanId = p_loan_id;

    IF EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 1 AND 9 THEN 
        IF EXTRACT(ISODOW FROM CURRENT_DATE) < 6 THEN 
            late_fee := days_late * 0.3;
        ELSE 
            late_fee := days_late * 0.2;
        END IF;
    ELSE 
        IF EXISTS (SELECT 1 FROM Loan
                   JOIN Copies ON Loan.copyId = Copies.copyId
                   JOIN Books ON Copies.bookId = Books.bookId
                   WHERE Loan.loanId = p_loan_id AND LOWER(Book.genre) LIKE '%school%') THEN
            late_fee := days_late * 0.5;
        ELSIF EXTRACT(ISODOW FROM CURRENT_DATE) < 6 THEN
            late_fee := days_late * 0.4;
        ELSE 
            late_fee := days_late * 0.2;
        END IF;
    END IF;

    RETURN late_fee;
END;
$$ LANGUAGE plpgsql;