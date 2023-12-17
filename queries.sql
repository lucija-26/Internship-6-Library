-- 1. ime, prezime, spol (ispisati ‘MUŠKI’, ‘ŽENSKI’, ‘NEPOZNATO’, ‘OSTALO’;), ime države i 
---prosječna plaća u toj državi svakom autoru


SELECT a.firstName, a.lastName, a.gender, c.name AS countryName, c.avgSalary
FROM Authors a
JOIN Countries c ON a.countryId = c.countryId;

-- 2. naziv i datum objave svake znanstvene knjige zajedno s imenima glavnih autora koji su na njoj radili

SELECT b.title, b.dateOfPublication, STRING_AGG(a.lastName || ', ' || LEFT(a.firstName, 1), '; ') AS Authors
FROM Books b
JOIN Authorship asp ON b.bookId = asp.bookId
JOIN Authors a ON asp.AuthorId = a.AuthorId
WHERE b.genre = 'scientific' AND asp.authorshipType = 'main'
GROUP BY b.bookId;

-- 3. sve kombinacije (naslova) knjiga i posudbi istih u prosincu 2023.; 
----u slučaju da neka nije ni jednom posuđena u tom periodu, prikaži je samo jednom

SELECT b.title, COALESCE(TO_CHAR(lo.loanDate, 'YYYY-MM-DD'), 'null') AS LoanDate
FROM Books b
LEFT JOIN Copies c ON b.BookId = c.BookId
LEFT JOIN Loans lo ON c.CopyId = lo.copyId AND lo.loanDate BETWEEN '2023-12-01' AND '2023-12-31'
WHERE (lo.loanDate BETWEEN '2023-12-01' AND '2023-12-31' OR lo.loanDate IS NULL);


-- 4. top 3 knjižnice s najviše primjeraka knjiga

SELECT l.Name, COUNT(*) AS TotalCopies
FROM Libraries l
JOIN Copies c ON l.LibraryId = c.LibraryId
GROUP BY l.libraryId
ORDER BY TotalCopies DESC
LIMIT 3;

-- 5. po svakoj knjizi broj ljudi koji su je pročitali (korisnika koji posudili bar jednom)

SELECT b.Title, COUNT(DISTINCT lo.userId) AS NumberOfReaders
FROM Books b
JOIN Copies c ON b.bookId = c.bookId
JOIN Loans lo ON c.CopyId = lo.copyId
GROUP BY b.bookId;

-- 6. imena svih korisnika koji imaju trenutno posuđenu knjigu

SELECT DISTINCT u.firstName, u.lastName
FROM Users u
JOIN Loans lo ON u.userId = lo.userId
WHERE lo.loanDate IS NULL;

-- 7. sve autore kojima je bar jedna od knjiga izašla između 2019. i 2022.

SELECT DISTINCT a.firstName, a.lastName
FROM Authors a
JOIN Authorship asp ON a.authorId = asp.authorId
JOIN Books b ON asp.bookId = b.bookId
WHERE b.dateOfPublication BETWEEN '2019-01-01' AND '2022-12-31';

-- 8. ime države i broj umjetničkih knjiga po svakoj (ako su dva autora iz iste države, računa se kao jedna knjiga)
--	  gdje su države sortirane po broju živih autora od najveće ka najmanjoj 

SELECT c.name, COUNT(DISTINCT b.bookId) AS ArtisticBooksCount
FROM Countries c
JOIN Authors a ON c.countryId = a.countryId
JOIN Authorship asp ON a.authorId = asp.authorId
JOIN Books b ON asp.bookId = b.bookId
WHERE b.genre = 'artistic'
GROUP BY c.countryId
ORDER BY COUNT(DISTINCT a.authorId) DESC;

-- 9. po svakoj kombinaciji autora i žanra (ukoliko postoji) broj posudbi knjiga tog autora u tom žanru

SELECT a.firstName, a.lastName, b.genre, COUNT(lo.loanId) AS NumberOfLoans
FROM Authors a
JOIN Authorship asp ON a.authorId = asp.authorId
JOIN Books b ON asp.bookId = b.bookId
JOIN Copies c ON b.bookId = c.bookId
JOIN Loans lo ON c.copyId = lo.copyId
GROUP BY a.authorId, b.genre;

-- 10. po svakom članu koliko trenutno duguje zbog kašnjenja; u slučaju da ne duguje ispiši “ČISTO”

SELECT u.firstName, u.lastName, CASE 
  WHEN lo.dueDate < CURRENT_DATE THEN 'Duguje'
  ELSE 'ČISTO'
END AS Status
FROM Users u
JOIN Loans lo ON u.userId = lo.userId;

-- 11. autora i ime prve objavljene knjige istog

SELECT a.firstName, a.lastName, b.title AS FirstBook
FROM Authors a
JOIN Authorship asp ON a.authorId = asp.authorId
JOIN Books b ON asp.bookId = b.bookId
WHERE b.dateOfPublication = (
  SELECT MIN(b2.dateOfPublication)
  FROM Books b2
  JOIN Authorship asp2 ON b2.bookId = asp2.bookId
  WHERE asp2.authorId = a.authorId
)
GROUP BY a.authorId, b.bookId;

-- 12. državu i ime druge objavljene knjige iste

SELECT c.name, b2.title
FROM Books b1
JOIN Authorship asp ON b1.bookId = asp.bookId
JOIN Authors a ON asp.authorId = a.authorId
JOIN Books b2 ON asp.authorId = a.authorId
JOIN Countries c ON a.countryId = c.countryId
WHERE b1.dateOfPublication <> b2.dateOfPublication
    AND a.countryId = (
        SELECT a2.countryId
        FROM Books b3
        JOIN Authorship asp2 ON b3.bookId = asp2.bookId
        JOIN Authors a2 ON asp2.authorId = a2.authorId
        WHERE b3.dateOfPublication < b1.dateOfPublication
        ORDER BY b3.dateOfPublication DESC
        LIMIT 1
    )
ORDER BY b2.dateOfPublication
LIMIT 1;

-- 13. knjige i broj aktivnih posudbi, gdje se one s manje od 10 aktivnih ne prikazuju

SELECT b.title, COUNT(lo.loanId) AS ActiveLoans
FROM Books b
JOIN Copies c ON b.bookId = c.bookId
JOIN Loans lo ON c.copyId = lo.copyId
WHERE lo.dueDate IS NULL
GROUP BY b.title
HAVING COUNT(lo.loanId) > 10;

-- 14. prosječan broj posudbi po primjerku knjige po svakoj državi

SELECT c.name AS country_name, AVG(lo.LoanCount) AS AvgLoansPerCopy
FROM Countries c
JOIN Authors a ON c.countryId = a.countryId
JOIN Authorship asp ON a.authorId = asp.authorId
JOIN Books b ON asp.bookId = b.bookId
JOIN Copies co ON b.bookId = co.bookId
LEFT JOIN (
    SELECT co2.copyId, COUNT(*) AS LoanCount
    FROM Copies co2
    JOIN Loans lo2 ON co2.copyId = lo2.copyId
    GROUP BY co2.copyId
) AS lo ON co.copyId = lo.copyId
GROUP BY c.name;

-- 15. broj autora (koji su objavili više od 5 knjiga) po struci, desetljeću rođenja i spolu; 
----u slučaju da je broj autora manji od 10, ne prikazuj kategoriju; poredaj prikaz po desetljeću rođenja

SELECT EXTRACT(DECADE FROM a.birthDate) AS BirthDecade, a.gender, COUNT(a.authorId) AS AuthorCount
FROM Authors a
JOIN Authorship asp ON a.authorId = asp.authorId
GROUP BY EXTRACT(DECADE FROM a.birthDate), a.gender
HAVING COUNT(a.authorId) > 5
ORDER BY BirthDecade;


-- 16. 10 najbogatijih autora

WITH BookCounts AS (
    SELECT
        a2.authorId,
        COUNT(DISTINCT a2.bookId) AS NumBooks
    FROM
        Authorship a2
    GROUP BY
        a2.authorId
),
CopyCounts AS (
    SELECT
        a3.authorId,
        COUNT(DISTINCT c.copyId) AS NumCopies
    FROM
        Authorship a3
    JOIN
        Copies c ON a3.bookId = c.bookId
    GROUP BY
        a3.authorId
)

SELECT
    a.firstName,
    a.lastName,
    SUM(SQRT(1.0 * cc.NumCopies) / bc.NumBooks) AS Wealth
FROM
    Authors a
JOIN
    BookCounts bc ON a.authorId = bc.authorId
JOIN
    CopyCounts cc ON a.authorId = cc.authorId
GROUP BY
    a.authorId
ORDER BY
    Wealth DESC
LIMIT 10;
