from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user import User
from app.auth.password import hash_password, verify_password
from app.auth.jwt import create_access_token
from app.utils.id_generator import generate_code


def create_user(
    db: Session,
    user_data
):

    count = db.query(User).count()

    employee_id = generate_code(
        "EMP",
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



def login_user(
    db: Session,
    mobile: str,
    password: str
):

    user = (
        db.query(User)
        .filter(User.mobile == mobile)
        .first()
    )


    if not user:

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password"
        )


    if not verify_password(
        password,
        user.password_hash
    ):

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password"
        )


    token_data = {

        "user_id": user.id,

        "sub": user.mobile,

        "role": user.role

    }


    access_token = create_access_token(
        token_data
    )


    return {

        "access_token": access_token,

        "token_type": "bearer"

    }
