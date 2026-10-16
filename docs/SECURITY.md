# Security Policy for DSA HeroApp

## Overview

This document outlines the security practices and vulnerabilities management for the DSA HeroApp project.

## Reporting Security Vulnerabilities

**Do not open public issues for security vulnerabilities.**

Please email security concerns to the project maintainer with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

## Security Updates

We aim to patch critical vulnerabilities within 48 hours of discovery.

## Known Security Considerations

### Firebase Configuration

- **Credentials Management**: Firebase configuration files (`.firebaserc`, `firebase.json`) are NOT committed to the repository. Use Firebase CLI to configure locally.
- **Project ID**: The Firebase project ID is public (part of Firebase design), but access control is managed through Firestore/Storage Security Rules.

### Authentication

- Firebase Authentication is used for sensitive operations
- Anonymous access is restricted to group code-based sharing only
- All user-specific data requires authentication

### Data Storage

#### Firestore Security Rules

- **Group Access**: Groups can be read with a valid 20+ character alphanumeric code
- **User Data**: Only authenticated users can access their own user documents
- **Size Limits**: Enforced limits prevent DoS attacks
  - Heroes: 256 KB per document
  - Hero States: 100 KB per document
  - Private Settings: 16 KB per document
  - Max 100 heroes per user

#### Cloud Storage Rules

- **Avatar Uploads**: 
  - Only authenticated users can upload to their own avatar directory
  - File types restricted to JPEG, PNG, WebP
  - Maximum file size: 5 MB
  - SVG and other potentially dangerous formats are blocked

### CORS Configuration

- **Allowed Origins**: Only whitelisted Firebase hosting domains and localhost (for development)
- **Wildcard Origins**: NOT used in production

### API Communication

- **Windows Sync**: Uses Firestore REST API with Firebase Auth ID tokens
- **SSL/TLS**: All communication uses HTTPS
- **Future Improvements**: SSL Certificate Pinning recommended for sensitive data

### Dependencies

Regularly update dependencies to patch known vulnerabilities:

```bash
flutter pub outdated
flutter pub upgrade
```

Key security-related packages:
- `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage`: Official Firebase SDKs
- `flutter_secure_storage`: Platform-specific secure storage
- `pointycastle`: Cryptography library (kept up-to-date)

## Security Best Practices

1. **Never commit secrets**:
   - Firebase configuration
   - API keys
   - Private keys
   - Environment variables

2. **Code Review**: All changes undergo code review before merging

3. **Testing**: Security tests are included in the test suite

4. **Dependency Management**: Keep all packages updated

5. **Error Handling**: Avoid exposing sensitive information in error messages

## Firebase Emulator (Development)

When using Firebase Emulator Suite locally:
- Emulator runs on `localhost` only
- Rules are still validated
- No real data is affected

## Compliance

- Personal data is stored in encrypted form where possible
- User data in Firestore is only accessible by the authenticated user
- GDPR considerations: Users can export/delete their data

## Changelog

### v1.0.1 (October 2026)
- Added security documentation
- Hardened Firestore Security Rules
- Restricted Cloud Storage to JPEG/PNG/WebP
- Removed wildcard CORS origin
- Added rate limiting recommendations
