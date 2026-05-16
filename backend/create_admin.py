from database import SessionLocal
from models import User
from passlib.context import CryptContext # Thư viện băm mật khẩu thường dùng trong FastAPI

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

def seed_admin():
    db = SessionLocal()
    email = "admin@system.com"
    
    # Kiểm tra xem admin đã tồn tại chưa
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        print("Tài khoản admin đã tồn tại!")
        return

    # Tạo user mới và ép quyền (role) là admin
    admin_user = User(
        email=email,
        password_hash=get_password_hash("Admin@123456"), # Mật khẩu mặc định
        full_name="Super Admin",
        role="ADMIN",  # Ép quyền admin ở đây
        is_active=True
    )
    
    db.add(admin_user)
    db.commit()
    print(f"Đã ép tạo thành công tài khoản admin: {email}")
    db.close()

if __name__ == "__main__":
    seed_admin()