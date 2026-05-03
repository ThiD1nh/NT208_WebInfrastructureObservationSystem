-- ===========================================================================
-- Setup database bằng MySQL trong file `init.sql` và cố tình tạo lỗi để test
-- ===========================================================================

CREATE DATABASE IF NOT EXISTS observationsystem_db;
USE observationsystem_db;

-- ===========================================================================
-- 1. BẢNG USERS (KHÔNG CÓ LỖI)
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    user_name VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- ===========================================================================


-- ===========================================================================
-- 2. BẢNG PRODUCTS (DỰ ĐOÁN SẼ GÂY RA LỖI CRASH APP, ERROR 500)

-- Cố tình dùng kiểu dữ liệu `UNSIGNED` cho cột stock_quantity để nó luôn không âm.
-- Cách khai thác: Viết 1 API "Đặt hàng".
-- Kết quả dự đoán: Khi API trừ số lượng hàng trong kho, nếu khách mua 5 cái mà kho chỉ còn 3 cái, MySQL sẽ báo lỗi -> App bị lỗi 500.

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL UNIQUE,
    stock_quantity INT UNSIGNED NOT NULL    -- Cố tình tạo ra lỗi: Ép số lượng không được âm
);
--- ===========================================================================


-- ===========================================================================
-- 3. BẢNG ORDERS (DỰ ĐOÁN SẼ GÂY RA LỖI BOTTLENECK, TRẢ VỀ KẾT QUẢ CHẬM)

-- Cố tình không đánh index cho cột status.
-- Cách khai thác: Viết 1 API "Lấy danh sách đơn hàng đang chờ xử lý (status = pending)".
-- Kết quả dự đoán: Vì không có index, kèm theo dữ liệu nhiều (có code để chèn dữ liệu vào db ở dưới), MySQL sẽ phải đi quét toàn bộ bảng -> Thời gian đợi phản hồi sẽ tăng cao.

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL, CONSTRAINT fk_orders_userid FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    total_amount DECIMAL(12, 3) NOT NULL,
    status ENUM('pending', 'completed') NOT NULL,            -- Cố tình tạo ra lỗi: Không đánh index
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- ===========================================================================

-- LƯU Ý: Nếu đúng thì bảng PRODUCTS và ORDERS sẽ có quan hệ với nhau thông qua một bảng trung gian nữa (để biết đơn hàng đó có những sản phẩm nào, số lượng, tổng tiền bao nhiêu,...) nhưng ở đây mục đích chính là test lỗi nên sẽ bỏ qua cái đó.

-- ===========================================================================
-- 4. CHÈN DỮ LIỆU MẪU VÀO CÁC BẢNG

-- Thêm người dùng mẫu vào bảng USERS và sản phẩm mẫu vào bảng PRODUCTS.
INSERT INTO users (user_name, email) VALUES 
('nguyenvanan632', 'annguyenvan632@gmail.com'),
('tranthibich434', 'bichtranthi434@gmail.com'),
('legiachi233', 'chilegia233@gmail.com');

INSERT INTO products (product_name, stock_quantity) VALUES 
('Laptop A', 3),    -- Cho sản phẩm Laptop chỉ còn 3 cái, dùng để test lỗi ERROR 500
('Chuột B', 690),
('Bàn phím C', 75);

-- Dùng Stored Procedure để tạo nhanh 50.000 dòng dữ liệu rác vào bảng ORDERS, dùng để test lỗi bottleneck
DELIMITER $$
CREATE PROCEDURE SeedDummyOrders()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 50000 DO
        INSERT INTO orders (user_id, total_amount, status)
        VALUES (
            FLOOR(1 + RAND() * 3),   -- Random user_id từ 1 đến 3
            ROUND(RAND() * 1000, 3),    -- Random số tiền thanh toán của đơn hàng
            IF(MOD(i, 5) = 0, 'pending', 'completed')   -- Cứ 5 đơn thì sẽ có 1 đơn trạng thái pending
        );
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

-- Chạy hàm chèn dữ liệu
CALL SeedDummyOrders();

-- Xóa hàm sau khi chạy xong
DROP PROCEDURE SeedDummyOrders;
-- ===========================================================================