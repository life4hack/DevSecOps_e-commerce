# The first instruction is what image we want to base our container on
# We Use an official Python runtime as a parent image
FROM python:3.12-alpine

# Mounts the application code to the image
COPY . app
WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port
EXPOSE 8000

# runserver
ENTRYPOINT ["python", "manage.py"]
CMD ["runserver", "0.0.0.0:8000"]
