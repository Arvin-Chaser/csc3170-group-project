USE CompanyManager;

/*
  查询脚本说明
  - 直接执行前可先修改下方参数变量
  - 所有查询基于当前 data.sql 中的表结构
*/

-- ===== 参数区（按需修改）=====
SET @emp_id = 25;
SET @manager_id = 8;
SET @project_id = 3;
SET @client_id = 201;
SET @department_id = 2;
SET @task_id = 5;
SET @last_name = '张';
SET @start_date = '2025-01-01';
SET @end_date = '2026-12-31';

-- =====================================================
-- 1) 查询某个员工的直属上级
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  s.Employee_ID AS Supervisor_ID,
  CONCAT(s.Last_Name, s.First_Name) AS Supervisor_Name
FROM Employee e
LEFT JOIN Employee s ON e.Supervisor_ID = s.Employee_ID
WHERE e.Employee_ID = @emp_id;

-- =====================================================
-- 2) 查询某个经理管理的所有下属
-- =====================================================
SELECT
  s.Employee_ID AS Manager_ID,
  CONCAT(s.Last_Name, s.First_Name) AS Manager_Name,
  e.Employee_ID AS Subordinate_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Subordinate_Name,
  d.Department_Name
FROM Employee s
JOIN Employee e ON e.Supervisor_ID = s.Employee_ID
LEFT JOIN Department d ON e.Department_ID = d.Department_ID
WHERE s.Employee_ID = @manager_id
ORDER BY e.Employee_ID;

-- =====================================================
-- 3) 查询某段时间内新入职的员工
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  e.Hire_date,
  d.Department_Name
FROM Employee e
LEFT JOIN Department d ON e.Department_ID = d.Department_ID
WHERE e.Hire_date BETWEEN @start_date AND @end_date
ORDER BY e.Hire_date, e.Employee_ID;

-- =====================================================
-- 4) 查询某个项目的项目经理姓名、客户信息、以及参与部门名称
-- =====================================================
SELECT
  p.Project_ID,
  p.Project_Name,
  CONCAT(pm.Last_Name, pm.First_Name) AS Project_Manager_Name,
  COALESCE(GROUP_CONCAT(DISTINCT c.Name ORDER BY c.Name SEPARATOR ', '), 'None') AS Clients,
  COALESCE(GROUP_CONCAT(DISTINCT d.Department_Name ORDER BY d.Department_Name SEPARATOR ', '), 'None') AS Participating_Departments
FROM Project p
LEFT JOIN Employee pm ON p.Project_Manager_ID = pm.Employee_ID
LEFT JOIN Client_Project cp ON p.Project_ID = cp.Project_ID
LEFT JOIN Client c ON cp.Client_id = c.Client_id
LEFT JOIN Task t ON p.Project_ID = t.Project_ID
LEFT JOIN Department d ON t.Department_ID = d.Department_ID
WHERE p.Project_ID = @project_id
GROUP BY p.Project_ID, p.Project_Name, pm.Employee_ID, pm.Last_Name, pm.First_Name;

-- =====================================================
-- 5A) 统计每个员工的考勤记录数量
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  COUNT(a.Date) AS Attendance_Record_Count
FROM Employee e
LEFT JOIN Attendance a ON e.Employee_ID = a.Employee_ID
GROUP BY e.Employee_ID, e.Last_Name, e.First_Name
ORDER BY e.Employee_ID;

-- =====================================================
-- 5B) 统计每个员工缺勤次数
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) AS Absent_Count
FROM Employee e
LEFT JOIN Attendance a ON e.Employee_ID = a.Employee_ID
GROUP BY e.Employee_ID, e.Last_Name, e.First_Name
ORDER BY Absent_Count DESC, e.Employee_ID;

-- =====================================================
-- 6) 查询某员工的薪资发放历史
-- =====================================================
SELECT
  sr.Record_id,
  sr.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  sr.Amount,
  sr.Bonus,
  (sr.Amount + COALESCE(sr.Bonus, 0)) AS Total_Pay,
  sr.Date
FROM Salary_Record sr
JOIN Employee e ON sr.Employee_ID = e.Employee_ID
WHERE sr.Employee_ID = @emp_id
ORDER BY sr.Date DESC, sr.Record_id DESC;

-- =====================================================
-- 7) 查询某个客户所有项目对应的项目经理
-- =====================================================
SELECT
  c.Client_id,
  c.Name AS Client_Name,
  p.Project_ID,
  p.Project_Name,
  CONCAT(pm.Last_Name, pm.First_Name) AS Project_Manager_Name
FROM Client c
JOIN Client_Project cp ON c.Client_id = cp.Client_id
JOIN Project p ON cp.Project_ID = p.Project_ID
LEFT JOIN Employee pm ON p.Project_Manager_ID = pm.Employee_ID
WHERE c.Client_id = @client_id
ORDER BY p.Project_ID;

-- =====================================================
-- 8) 查询某个部门参与的所有项目及其客户名称
-- =====================================================
SELECT
  d.Department_ID,
  d.Department_Name,
  p.Project_ID,
  p.Project_Name,
  COALESCE(GROUP_CONCAT(DISTINCT c.Name ORDER BY c.Name SEPARATOR ', '), 'None') AS Client_Names
FROM Department d
JOIN Task t ON d.Department_ID = t.Department_ID
JOIN Project p ON t.Project_ID = p.Project_ID
LEFT JOIN Client_Project cp ON p.Project_ID = cp.Project_ID
LEFT JOIN Client c ON cp.Client_id = c.Client_id
WHERE d.Department_ID = @department_id
GROUP BY d.Department_ID, d.Department_Name, p.Project_ID, p.Project_Name
ORDER BY p.Project_ID;

-- =====================================================
-- 9) 查询所有姓为某某的员工
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  d.Department_Name,
  e.Hire_date
FROM Employee e
LEFT JOIN Department d ON e.Department_ID = d.Department_ID
WHERE e.Last_Name = @last_name
ORDER BY e.Employee_ID;

-- =====================================================
-- 10) 统计参与某任务的所有员工及其角色
-- =====================================================
SELECT
  t.Task_ID,
  t.Task_name,
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  ta.Role_in_Task
FROM Task t
JOIN Task_Assignment ta ON t.Task_ID = ta.Task_ID
JOIN Employee e ON ta.Employee_ID = e.Employee_ID
WHERE t.Task_ID = @task_id
ORDER BY e.Employee_ID;

-- =====================================================
-- 11) 查询所有涉及（worker / manager）某位员工的项目
--     改进：同一项目只显示一行，并合并角色
-- =====================================================
SELECT
  x.Project_ID,
  x.Project_Name,
  GROUP_CONCAT(DISTINCT x.Involved_As ORDER BY x.Involved_As SEPARATOR ', ') AS Involved_Roles
FROM (
  SELECT
    p.Project_ID,
    p.Project_Name,
    'Manager' AS Involved_As
  FROM Project p
  WHERE p.Project_Manager_ID = @emp_id

  UNION ALL

  SELECT
    p.Project_ID,
    p.Project_Name,
    'Worker' AS Involved_As
  FROM Project p
  JOIN Task t ON p.Project_ID = t.Project_ID
  JOIN Task_Assignment ta ON t.Task_ID = ta.Task_ID
  WHERE ta.Employee_ID = @emp_id
) x
GROUP BY x.Project_ID, x.Project_Name
ORDER BY x.Project_ID;

-- =====================================================
-- 12) 查询没有被分配任何任务的员工
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  d.Department_Name
FROM Employee e
LEFT JOIN Task_Assignment ta ON e.Employee_ID = ta.Employee_ID
LEFT JOIN Department d ON e.Department_ID = d.Department_ID
WHERE ta.Task_ID IS NULL
ORDER BY e.Employee_ID;

-- =====================================================
-- 13) 查询没有下属的员工
-- =====================================================
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  d.Department_Name
FROM Employee e
LEFT JOIN Employee sub ON sub.Supervisor_ID = e.Employee_ID
LEFT JOIN Department d ON e.Department_ID = d.Department_ID
WHERE sub.Employee_ID IS NULL
ORDER BY e.Employee_ID;


/* =====================================================
   分析类查询
   ===================================================== */

-- A1) 员工在给定时间范围内工作活跃度
-- 活跃度 = 0.7 * 任务数 + 0.3 * 涉及项目数
-- 任务时间范围近似视为 [Begin_date, Deadline]，与查询区间有重叠即计入
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  COUNT(DISTINCT t.Task_ID) AS Task_Count,
  COUNT(DISTINCT t.Project_ID) AS Project_Count,
  ROUND(
    0.7 * COUNT(DISTINCT t.Task_ID) + 0.3 * COUNT(DISTINCT t.Project_ID),
    2
  ) AS Activity_Score
FROM Employee e
LEFT JOIN Task_Assignment ta ON e.Employee_ID = ta.Employee_ID
LEFT JOIN Task t
  ON ta.Task_ID = t.Task_ID
 AND t.Begin_date <= @end_date
 AND (t.Deadline IS NULL OR t.Deadline >= @start_date)
GROUP BY e.Employee_ID, e.Last_Name, e.First_Name
ORDER BY Activity_Score DESC, e.Employee_ID;

-- A2) 员工在给定时间范围内出勤率
-- 出勤率 = (On-time + Late) / 总记录数
SELECT
  e.Employee_ID,
  CONCAT(e.Last_Name, e.First_Name) AS Employee_Name,
  SUM(CASE WHEN a.Status IN ('On-time', 'Late') THEN 1 ELSE 0 END) AS Present_Count,
  SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) AS Absent_Count,
  COUNT(a.Date) AS Total_Attendance_Records,
  ROUND(
    CASE
      WHEN COUNT(a.Date) = 0 THEN 0
      ELSE SUM(CASE WHEN a.Status IN ('On-time', 'Late') THEN 1 ELSE 0 END) / COUNT(a.Date)
    END,
    4
  ) AS Attendance_Rate
FROM Employee e
LEFT JOIN Attendance a
  ON e.Employee_ID = a.Employee_ID
 AND a.Date BETWEEN @start_date AND @end_date
GROUP BY e.Employee_ID, e.Last_Name, e.First_Name
ORDER BY Attendance_Rate DESC, e.Employee_ID;

-- A3) 部门真实工作负荷分析
-- 输出：实际参与项目数、部门员工数、任务分配记录数、员工人均分配数
SELECT
  d.Department_ID,
  d.Department_Name,
  COUNT(DISTINCT t.Project_ID) AS Participated_Project_Count,
  COUNT(DISTINCT e.Employee_ID) AS Employee_Count,
  COUNT(DISTINCT CONCAT(ta.Employee_ID, '-', ta.Task_ID)) AS Assignment_Count,
  ROUND(
    CASE
      WHEN COUNT(DISTINCT e.Employee_ID) = 0 THEN 0
      ELSE COUNT(DISTINCT CONCAT(ta.Employee_ID, '-', ta.Task_ID)) / COUNT(DISTINCT e.Employee_ID)
    END,
    2
  ) AS Avg_Assignments_Per_Employee
FROM Department d
LEFT JOIN Employee e ON d.Department_ID = e.Department_ID
LEFT JOIN Task_Assignment ta ON e.Employee_ID = ta.Employee_ID
LEFT JOIN Task t ON ta.Task_ID = t.Task_ID
GROUP BY d.Department_ID, d.Department_Name
ORDER BY Assignment_Count DESC, d.Department_ID;
