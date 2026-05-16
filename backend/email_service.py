"""
Email service.

- Gửi OTP kích hoạt tài khoản
- Gửi OTP đặt lại mật khẩu
- Nếu chưa cấu hình SMTP_EMAIL/SMTP_PASSWORD trong .env:
    + Log OTP ra console để dev có thể test
    + Không raise exception (giúp luồng test local hoạt động)
"""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_EMAIL = os.getenv("SMTP_EMAIL")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
APP_NAME = os.getenv("APP_NAME", "DocGen VN")
APP_URL = os.getenv("APP_URL", "https://docgenvn.id.vn")


# ─────────────────────────────────────────────────────────────
# HTML TEMPLATE
# ─────────────────────────────────────────────────────────────
def _build_html(title: str, intro: str, otp: str, note: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;font-family:Arial,sans-serif;background:#f4f6fb;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0"
        style="background:#ffffff;border-radius:12px;overflow:hidden;
               box-shadow:0 4px 16px rgba(0,0,0,0.06);">
        <tr><td style="background:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%);
                       padding:32px 40px;color:#fff;">
          <h1 style="margin:0;font-size:24px;">{APP_NAME}</h1>
          <p style="margin:8px 0 0;opacity:0.85;">{title}</p>
        </td></tr>
        <tr><td style="padding:32px 40px;color:#1f2937;">
          <p style="margin:0 0 16px;font-size:15px;line-height:1.6;">{intro}</p>
          <div style="margin:24px 0;padding:20px;background:#f3f4f6;border-radius:8px;
                      text-align:center;">
            <div style="font-size:14px;color:#6b7280;margin-bottom:8px;">
              Mã xác thực của bạn
            </div>
            <div style="font-size:36px;font-weight:bold;letter-spacing:8px;
                        color:#4F46E5;font-family:monospace;">{otp}</div>
          </div>
          <p style="margin:0;font-size:13px;color:#6b7280;line-height:1.6;">{note}</p>
        </td></tr>
        <tr><td style="padding:20px 40px;background:#f9fafb;color:#9ca3af;
                       font-size:12px;text-align:center;">
          © {APP_NAME} — <a href="{APP_URL}" style="color:#4F46E5;">{APP_URL}</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""


# ─────────────────────────────────────────────────────────────
# SEND
# ─────────────────────────────────────────────────────────────
def _send_email(receiver: str, subject: str, html: str, plain: str) -> bool:
    """
    Trả về True nếu gửi thành công, False nếu chưa cấu hình hoặc lỗi.
    KHÔNG raise — luồng đăng ký vẫn tiếp tục được khi local chưa có SMTP.
    """
    if not SMTP_EMAIL or not SMTP_PASSWORD:
        print(
            f"\n{'='*60}\n"
            f"[DEV MODE] SMTP chưa cấu hình. Mã/OTP gửi tới {receiver}:\n"
            f"{'='*60}\n{plain}\n{'='*60}\n"
        )
        return False

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{APP_NAME} <{SMTP_EMAIL}>"
    msg["To"] = receiver
    msg.attach(MIMEText(plain, "plain", "utf-8"))
    msg.attach(MIMEText(html, "html", "utf-8"))

    try:
        if SMTP_PORT == 465:
            with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT) as server:
                server.login(SMTP_EMAIL, SMTP_PASSWORD)
                server.send_message(msg)
        else:
            with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
                server.starttls()
                server.login(SMTP_EMAIL, SMTP_PASSWORD)
                server.send_message(msg)
        print(f"✅ Đã gửi email tới {receiver}: {subject}")
        return True
    except Exception as e:
        print(f"❌ Lỗi gửi email tới {receiver}: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────
def send_otp_email(receiver: str, otp: str) -> bool:
    """OTP kích hoạt tài khoản."""
    title = "Kích hoạt tài khoản"
    intro = (
        "Xin chào,<br>Cảm ơn bạn đã đăng ký tài khoản. "
        "Vui lòng nhập mã OTP bên dưới để kích hoạt tài khoản của bạn."
    )
    note = "Mã có hiệu lực trong <b>5 phút</b>. Nếu không phải bạn yêu cầu, hãy bỏ qua email này."
    html = _build_html(title, intro, otp, note)
    plain = (
        f"Xin chào,\n\nMã OTP kích hoạt tài khoản {APP_NAME} của bạn là: {otp}\n"
        f"Mã có hiệu lực trong 5 phút.\n"
    )
    return _send_email(receiver, f"Mã xác thực {APP_NAME}", html, plain)


def send_reset_password_email(receiver: str, otp: str) -> bool:
    """OTP đặt lại mật khẩu."""
    title = "Đặt lại mật khẩu"
    intro = (
        "Xin chào,<br>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn. "
        "Vui lòng nhập mã OTP bên dưới để xác nhận."
    )
    note = (
        "Mã có hiệu lực trong <b>5 phút</b>. "
        "Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này và bảo mật tài khoản."
    )
    html = _build_html(title, intro, otp, note)
    plain = (
        f"Xin chào,\n\nMã OTP đặt lại mật khẩu {APP_NAME} của bạn là: {otp}\n"
        f"Mã có hiệu lực trong 5 phút.\n"
    )
    return _send_email(receiver, f"Đặt lại mật khẩu {APP_NAME}", html, plain)
