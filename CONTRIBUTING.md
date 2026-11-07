# Contributing to EduSync

Thank you for your interest in contributing to **EduSync**! We welcome bug reports, feature suggestions, UI/UX enhancements, and code contributions.

---

## Code of Conduct & Community Standards

All contributors and participants are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) and [Community Standards](COMMUNITY_STANDARDS.md).

---

## Getting Started

1. **Fork the Repository** to your own GitHub account.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/edusync.git
   cd edusync
   ```
3. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Create a Topic Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## Development & Code Quality Guidelines

Before submitting any code changes, ensure all automated checks pass:

1. **Static Analysis**:
   ```bash
   flutter analyze
   ```
   *Must report 0 issues.*

2. **Automated Unit & Widget Tests**:
   ```bash
   flutter test
   ```
   *All tests must pass.*

3. **Security Standards**:
   - Never commit private API keys, keystores, or `.env` files.
   - Follow [SECURITY.md](SECURITY.md) guidelines.

---

## Submitting Pull Requests

1. Commit your changes with clear, descriptive commit messages:
   ```bash
   git commit -m "Add feature: class QR code scanner for student enrollment"
   ```
2. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
3. Open a **Pull Request** against the `main` branch of `Kioian89/edusync`.
4. Provide a clear description of your changes, screenshots for UI modifications, and link any related issues.
