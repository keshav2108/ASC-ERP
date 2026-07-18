from datetime import datetime

from pydantic import BaseModel



class CustomerProductCreate(BaseModel):

    customer_id: int

    brand: str

    product_name: str

    model_number: str | None = None

    serial_number: str | None = None

    purchase_date: datetime | None = None

    warranty_status: str = "OUT"




class CustomerProductResponse(BaseModel):

    id: int

    customer_id: int

    brand: str

    product_name: str

    model_number: str | None

    serial_number: str | None

    purchase_date: datetime | None

    warranty_status: str

    created_at: datetime


    class Config:

        from_attributes = True
