from sqlalchemy.orm import Session

from app.models.user import User
from app.auth.password import hash_password
from app.utils.id_generator import generate_employee_id


def create_user(
    db: Session,
    user_data
):

    count = db.query(User).count()

    employee_id = generate_employee_id(
        count + 1
    )

    new_user = User(

        employee_id=employee_id,

        full_name=user_data.full_name,

        email=user_data.email,

        mobile=user_data.mobile,

        password_hash=hash_password(
            user_data.password
        ),

        role=user_data.role

    )


    db.add(new_user)

    db.commit()

    db.refresh(new_user)

    return new_user
