<?php
$host = getenv('DB_HOST');
$user = getenv('DB_USER');
$pass = getenv('DB_PASSWORD');
$db   = getenv('DB_NAME');
 
$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
echo "Connected to MySQL successfully!";
$result = $conn->query("SELECT NOW() as time");
$row = $result->fetch_assoc();
echo "<br>DB Time: " . $row['time'];
?>
