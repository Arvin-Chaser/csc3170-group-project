import os
from dotenv import load_dotenv

# 强制重新加载.env文件
load_dotenv('.env', override=True)

# 数据库连接配置（从.env读取）
DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "CompanyManager")
}

# Schema描述（核心信息）
SCHEMA_DESCRIPTION = """
数据库表结构:
- Department(Department_ID, Department_Name, Department_Manager_ID)
- Employee(Employee_ID, First_Name, Last_Name, Department_ID, Address, Phone_Number, Hire_date, Supervisor_ID)
- Project(Project_ID, Project_Name, Start_date, End_date, Budget, Project_Manager_ID)
- Task(Task_ID, Project_ID, Task_name, Begin_date, Deadline, Status, Department_ID)
- Task_Assignment(Employee_ID, Task_ID, Role_in_Task)
- Attendance(Employee_ID, Date, Status)
- Salary_Record(Record_id, Employee_ID, Amount, Bonus, Date)
- Client(Client_id, Name, Phone_number)
- Client_Project(Client_id, Project_ID)

外键关系:
- Employee.Department_ID → Department.Department_ID
- Employee.Supervisor_ID → Employee.Employee_ID
- Project.Project_Manager_ID → Employee.Employee_ID
- Task.Project_ID → Project.Project_ID
- Task.Department_ID → Department.Department_ID
- Task_Assignment.Employee_ID → Employee.Employee_ID
- Task_Assignment.Task_ID → Task.Task_ID
- Attendance.Employee_ID → Employee.Employee_ID
- Salary_Record.Employee_ID → Employee.Employee_ID
- Client_Project.Client_id → Client.Client_id
- Client_Project.Project_ID → Project.Project_ID

注意:
- 员工姓名需用 CONCAT(Last_Name, First_Name) 组合
- 中文表名和字段名直接使用
- 状态字段有: Pending, Doing, Done, On-time, Late, Absent
"""