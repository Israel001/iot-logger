from datetime import datetime, date
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field

class LocationCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    description: Optional[str] = None
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None

class SensorCreate(BaseModel):
    sensor_code: str = Field(..., min_length=3, max_length=50)
    location_id: int
    sensor_type: str = "environment"
    temperature_min: Decimal = Decimal("10.00")
    temperature_max: Decimal = Decimal("40.00")
    humidity_min: Decimal = Decimal("20.00")
    humidity_max: Decimal = Decimal("80.00")

class SensorReadingCreate(BaseModel):
    sensor_code: str = Field(..., min_length=3, max_length=50)
    recorded_at: datetime
    temperature: Decimal
    humidity: Decimal

class DailyAverageRow(BaseModel):
    sensor_id: int
    sensor_code: str
    location_name: str
    reading_date: date
    avg_temperature: Decimal
    avg_humidity: Decimal
    reading_count: int

class AnomalyRow(BaseModel):
    id: int
    sensor_id: int
    sensor_code: str
    location_name: str
    recorded_at: datetime
    temperature: Decimal
    humidity: Decimal
    anomaly_type: str
