# Presenter Notes

This deck is designed for a group presentation to a lecturer. The slide order is short enough for a focused class presentation, but detailed enough to show the technical depth of the project.

Before presenting:

- Replace the team placeholder on slide 1 with your real names.
- If your lecturer expects course metadata, add department, course code, and lecturer name on slide 1.
- Keep the delivery simple and confident. The deck already explains the project in plain language.

## Suggested speaker split

- Speaker 1: Slides 1-2
- Speaker 2: Slides 3-5
- Speaker 3: Slides 6-8
- Speaker 4: Slides 9-10

If your group has more than four members, split slide 8 or slide 9 into two speakers.

## Slide-by-slide talking points

### Slide 1 - Title

- Introduce the project as an IoT Data Logging System built for Exercise 5.
- State that the project focuses on the software side of IoT: data storage, APIs, analytics, and dashboard reporting.

### Slide 2 - Problem, Objective, and Deliverables

- Explain the problem: raw sensor data becomes difficult to track manually when readings increase over time.
- Explain the objective: build a structured system that stores sensor data, analyzes it, and presents useful reports.
- Point out the project deliverables: PostgreSQL schema, FastAPI backend, reporting logic, and dashboard.

### Slide 3 - What IoT Means Here

- Define IoT in simple terms for the lecturer and class.
- Make it clear that this repository simulates the IoT workflow instead of connecting to physical hardware.
- Emphasize the difference between what is implemented and what is only represented logically.

### Slide 4 - System Architecture

- Walk through the flow from sensor data to dashboard display.
- Explain that a reading enters through the API, gets stored in PostgreSQL, and then feeds reports and dashboard views.
- Mention that `init-db` and `seed-db` are helper services for preparing demo data.

### Slide 5 - Database Design

- Explain the purpose of the three core tables: `locations`, `sensors`, and `sensor_readings`.
- Mention why thresholds are stored with sensors.
- Point out that the views and function add reporting and business logic inside the database.
- Mention partitioning and indexes as performance-oriented design choices.

### Slide 6 - Backend and API

- Explain that FastAPI acts as the layer between users and the database.
- Highlight the route groups: locations, sensors, readings, daily averages, anomalies, and summary.
- Use the sample JSON to explain how a new reading is submitted.

### Slide 7 - Dashboard Walkthrough

- Show that the dashboard is designed for quick monitoring.
- Explain the purpose of the cards, recent readings table, anomaly section, daily averages, and input form.
- If asked, mention that the UI is lightweight because the project emphasis is on database design and reporting logic.

### Slide 8 - Demo Story and Analytics

- Use the `GH-A-001` example to explain the full journey of a reading.
- Explain how anomaly detection works:
  - threshold breach
  - sudden spike
- Mention the seeded abnormal values as examples used for testing the reports.

### Slide 9 - Strengths, Limitations, and Next Steps

- Present the current strengths confidently: structured schema, reporting logic, dashboard, clean API.
- Be honest about limitations: no live hardware, no broker, no authentication, and no real-time alerts yet.
- Frame the next steps as natural extension points rather than missing work.

### Slide 10 - Conclusion and Q&A

- End with three takeaways:
  - the project successfully models IoT data in a relational database
  - it exposes usable APIs and reports
  - it provides a dashboard for monitoring and analysis
- Invite questions.

## Delivery advice

- Avoid reading text directly from the slides.
- Use the slides as anchors and explain the ideas in your own words.
- When answering questions, keep returning to the main point: the project demonstrates how IoT data can be modeled, stored, analyzed, and presented in software.
