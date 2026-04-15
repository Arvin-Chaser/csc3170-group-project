-- 1. 环境初始化
CREATE DATABASE IF NOT EXISTS CompanyManager 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE CompanyManager;

-- 清理旧表
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Client_Project, Client, Salary_Record, Attendance, Task_Assignment, Task, Project, Employee, Department;
SET FOREIGN_KEY_CHECKS = 1;

-- 2. 建表

CREATE TABLE `Department` (
  `Department_ID` int PRIMARY KEY AUTO_INCREMENT,
  `Department_Name` varchar(255),
  `Department_Manager_ID` int UNIQUE
);

CREATE TABLE `Employee` (
  `Employee_ID` int PRIMARY KEY AUTO_INCREMENT,
  `First_Name` varchar(255),
  `Last_Name` varchar(255),
  `Department_ID` int NOT NULL,
  `Address` text,
  `Phone_Number` varchar(255),
  `Hire_date` date,
  `Supervisor_ID` int
);

CREATE TABLE `Project` (
  `Project_ID` int PRIMARY KEY AUTO_INCREMENT,
  `Project_Name` varchar(255),
  `Start_date` date,
  `End_date` date,
  `Budget` decimal(15,2),
  `Project_Manager_ID` int UNIQUE
);

CREATE TABLE `Task` (
  `Task_ID` int PRIMARY KEY AUTO_INCREMENT,
  `Project_ID` int NOT NULL,
  `Task_name` varchar(255),
  `Begin_date` date,
  `Deadline` date,
  `Status` varchar(255) DEFAULT 'Pending',
  `Department_ID` int
);

CREATE TABLE `Task_Assignment` (
  `Employee_ID` int,
  `Task_ID` int,
  `Role_in_Task` varchar(255),
  PRIMARY KEY (`Employee_ID`, `Task_ID`)
);

CREATE TABLE `Attendance` (
  `Employee_ID` int,
  `Date` date,
  `Status` varchar(255),
  PRIMARY KEY (`Employee_ID`, `Date`)
);

CREATE TABLE `Salary_Record` (
  `Record_id` int PRIMARY KEY AUTO_INCREMENT,
  `Employee_ID` int NOT NULL,
  `Amount` decimal(15,2),
  `Bonus` decimal(15,2),
  `Date` date
);

CREATE TABLE `Client` (
  `Client_id` int PRIMARY KEY,
  `Name` varchar(255),
  `Phone_number` varchar(255)
);

CREATE TABLE `Client_Project` (
  `Client_id` int,
  `Project_ID` int,
  PRIMARY KEY (`Client_id`, `Project_ID`)
);

-- 3. 数据导入

-- 插入部门
INSERT INTO `Department` (`Department_Name`) VALUES 
('总裁办'), ('研发部'), ('产品部'), ('市场部'), ('运营部'), 
('财务部'), ('人力资源部'), ('法务部'), ('售后服务部'), ('基础架构部');

-- 插入员工
INSERT INTO `Employee` (`First_Name`, `Last_Name`, `Department_ID`, `Address`, `Phone_Number`, `Hire_date`, `Supervisor_ID`)
WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 300
),
name_pool AS (
    SELECT 
        '王李张刘陈杨黄吴赵周徐孙马朱胡林郭罗高梁郑谢韩唐冯于董萧程曹袁邓许傅沈曾彭苏卢蒋蔡贾丁魏薛叶' AS last_pool,
        '伟刚勇毅俊峰强军平保东文辉力明永健世广志义兴良海山仁波贵福生龙元全国胜学才修林瑞天浩然宇航达芳艳玲云霞兰凤英莉慧梓一诺依琳欣怡梦琪语嫣思睿静雅婉婷佳悦颖璇璐姗沁雯芊涵月' AS first_pool
),
addr_pool AS (
    SELECT 
        '北京市,上海市,广州市,深圳市,杭州市,成都市,武汉市,南京市' AS cities,
        '中山路,解放路,人民路,建设路,延安路,幸福街,朝阳门外,科技园,金融街,友谊大道' AS roads,
        '花园,大厦,名邸,公寓,社区,新村,雅居,天山苑,金天地' AS zones
)
SELECT 
    COALESCE(
        CASE 
            WHEN RAND() > 0.4 THEN 
                CONCAT(
                    SUBSTR(first_pool, FLOOR(1 + RAND() * (CHAR_LENGTH(first_pool))), 1), 
                    SUBSTR(first_pool, FLOOR(1 + RAND() * (CHAR_LENGTH(first_pool))), 1)
                )
            ELSE 
                SUBSTR(first_pool, FLOOR(1 + RAND() * (CHAR_LENGTH(first_pool))), 1)
        END, 
    '伟') AS First_Name,
    COALESCE(SUBSTR(last_pool, FLOOR(1 + RAND() * (CHAR_LENGTH(last_pool))), 1), '张') AS Last_Name,
    FLOOR(1 + (RAND() * 10)), 
    CONCAT(
        SUBSTRING_INDEX(SUBSTRING_INDEX(cities, ',', FLOOR(1 + RAND() * 8)), ',', -1), 
        SUBSTRING_INDEX(SUBSTRING_INDEX(roads, ',', FLOOR(1 + RAND() * 10)), ',', -1),
        FLOOR(1 + RAND() * 500), '号',
        SUBSTRING_INDEX(SUBSTRING_INDEX(zones, ',', FLOOR(1 + RAND() * 9)), ',', -1),
        FLOOR(1 + RAND() * 20), '层', FLOOR(101 + RAND() * 800), '室'
    ) AS Address,
    CONCAT('13', FLOOR(100000000 + (RAND() * 899999999))),
    DATE_SUB(CURDATE(), INTERVAL FLOOR(RAND() * 1000) DAY),
    CASE WHEN n <= 10 THEN NULL ELSE FLOOR(1 + (RAND() * 10)) END
FROM seq, name_pool, addr_pool;

-- 插入经理
UPDATE `Department` SET `Department_Manager_ID` = Department_ID;

-- 插入项目
INSERT INTO `Project` (`Project_Name`, `Start_date`, `End_date`, `Budget`, `Project_Manager_ID`)
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 20)
SELECT CONCAT('核心项目-', n), '2024-01-01', '2025-12-31', (100000 + RAND() * 900000), n FROM seq;

-- 插入薪资
INSERT INTO `Salary_Record` (`Employee_ID`, `Amount`, `Bonus`, `Date`)
SELECT Employee_ID, (8000 + RAND() * 20000), (RAND() * 5000), '2026-03-31' FROM Employee;

-- 插入客户
INSERT INTO `Client` (`Client_id`, `Name`, `Phone_number`) VALUES 
(201, '阿里巴巴', '0571-8888'), (202, '腾讯', '0755-9999'), (203, '百度', '010-6666');

USE CompanyManager;

-- 插入任务
INSERT INTO `Task` (`Project_ID`, `Task_name`, `Begin_date`, `Deadline`, `Status`, `Department_ID`)
SELECT 
    p.Project_ID,
    CONCAT(p.Project_Name, '-阶段任务-', t.n),
    p.Start_date,
    DATE_ADD(p.Start_date, INTERVAL 30 DAY),
    ELT(FLOOR(1 + RAND() * 3), 'Pending', 'Doing', 'Done'), -- 随机状态
    FLOOR(1 + RAND() * 10) -- 随机指派给某个部门
FROM Project p
CROSS JOIN (SELECT 1 AS n UNION SELECT 2 UNION SELECT 3) t; -- 每个项目生成3个任务

-- 分配任务
INSERT IGNORE INTO `Task_Assignment` (`Employee_ID`, `Task_ID`, `Role_in_Task`)
SELECT 
    FLOOR(1 + RAND() * 300), -- 随机员工
    t.Task_ID,
    ELT(FLOOR(1 + RAND() * 4), 'Developer', 'Designer', 'Tester', 'Manager')
FROM Task t
CROSS JOIN (SELECT 1 AS n UNION SELECT 2) s; -- 每个任务随机分配2个人

-- 插入考勤
INSERT IGNORE INTO `Attendance` (`Employee_ID`, `Date`, `Status`)
SELECT 
    e.Employee_ID,
    d.dt,
    ELT(FLOOR(1 + RAND() * 3), 'On-time', 'Late', 'Absent')
FROM (SELECT Employee_ID FROM Employee LIMIT 50) e
CROSS JOIN (
    SELECT CURDATE() AS dt 
    UNION SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY)
    UNION SELECT DATE_SUB(CURDATE(), INTERVAL 2 DAY)
) d;

-- 插入关联
INSERT IGNORE INTO `Client_Project` (`Client_id`, `Project_ID`)
SELECT 
    c.Client_id,
    p.Project_ID
FROM Client c
CROSS JOIN (SELECT Project_ID FROM Project ORDER BY RAND() LIMIT 2) p; -- 每个客户随机关联2个项目

-- 4. 建立物理约束
ALTER TABLE `Employee` ADD CONSTRAINT `fk_emp_dept` FOREIGN KEY (`Department_ID`) REFERENCES `Department` (`Department_ID`);
ALTER TABLE `Employee` ADD CONSTRAINT `fk_emp_sup` FOREIGN KEY (`Supervisor_ID`) REFERENCES `Employee` (`Employee_ID`);
ALTER TABLE `Department` ADD CONSTRAINT `fk_dept_mgr` FOREIGN KEY (`Department_Manager_ID`) REFERENCES `Employee` (`Employee_ID`);
ALTER TABLE `Project` ADD CONSTRAINT `fk_proj_mgr` FOREIGN KEY (`Project_Manager_ID`) REFERENCES `Employee` (`Employee_ID`);
ALTER TABLE `Salary_Record` ADD CONSTRAINT `fk_sal_emp` FOREIGN KEY (`Employee_ID`) REFERENCES `Employee` (`Employee_ID`);

-- 5. 验证查询
SELECT * FROM employee;
