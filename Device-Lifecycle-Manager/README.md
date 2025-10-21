# Medical Device Lifecycle Tracker Smart Contract

## Overview

The Medical Device Lifecycle Tracker is a blockchain-based smart contract system built on the Stacks blockchain using Clarity. It provides a transparent and immutable solution for tracking medical devices throughout their entire lifecycle, from manufacturing through deployment, maintenance, and potential recalls. The system includes comprehensive regulatory certification management and recall tracking capabilities.

## Key Features

- Complete lifecycle tracking from manufacturing to disposal
- Regulatory certification management (FDA, CE, ISO, Safety Compliance)
- Device recall management with severity levels
- Batch recall capabilities for multiple devices
- Approved regulatory authority system
- Immutable audit trail for all device events
- Access control with administrative privileges

## Lifecycle Stages

The contract defines five distinct lifecycle stages:

1. **Manufactured** (u1) - Initial production stage
2. **Testing** (u2) - Quality assurance and validation phase
3. **Deployed** (u3) - Active use in medical facilities
4. **Maintained** (u4) - Regular maintenance and servicing
5. **Recalled** (u5) - Device has been recalled

## Certification Types

The system supports four regulatory certification types:

1. **FDA Approval** (u1) - US Food and Drug Administration
2. **CE Marking** (u2) - European Conformity
3. **ISO Standard** (u3) - International Organization for Standardization
4. **Safety Compliance** (u4) - General safety certifications

## Recall Severity Levels

Recalls are categorized by severity:

1. **Critical** (u1) - Life-threatening situations
2. **Major** (u2) - Significant health risk
3. **Minor** (u3) - Low health risk

## Core Functions

### Device Registration and Management

**register-device**
```clarity
(register-device (device-id uint) (initial-stage uint))
```
Registers a new medical device in the tracking system. Only administrators can register devices in stages other than manufactured.

**update-device-status**
```clarity
(update-device-status (device-id uint) (next-stage uint))
```
Updates the lifecycle stage of an existing device. Only the device owner or administrator can update status.

**get-device-status**
```clarity
(get-device-status (device-id uint))
```
Returns the current lifecycle stage of a device.

**get-device-history**
```clarity
(get-device-history (device-id uint))
```
Retrieves the complete lifecycle history of a device, including all status changes and timestamps.

### Certification Management

**add-regulatory-body**
```clarity
(add-regulatory-body (authority-address principal) (cert-value uint))
```
Adds an approved regulatory authority to the system. Administrator only.

**add-certification**
```clarity
(add-certification (device-id uint) (cert-value uint))
```
Issues a certification for a medical device. Can only be called by approved regulatory authorities.

**verify-certification**
```clarity
(verify-certification (device-id uint) (cert-value uint))
```
Verifies if a device holds a valid certification.

**revoke-certification**
```clarity
(revoke-certification (device-id uint) (cert-value uint))
```
Revokes a previously issued certification. Can be called by administrator or the issuing authority.

**get-certification-details**
```clarity
(get-certification-details (device-id uint) (cert-value uint))
```
Retrieves detailed information about a specific certification.

### Recall Management

**issue-device-recall**
```clarity
(issue-device-recall (device-id uint) (severity uint) (reason (string-ascii 256)) (affected-batches uint))
```
Issues a recall for a specific medical device. Administrator only. Automatically updates device status to recalled.

**resolve-device-recall**
```clarity
(resolve-device-recall (device-id uint))
```
Resolves an active recall after corrective action. Can be called by administrator or recall issuer.

**issue-batch-recall**
```clarity
(issue-batch-recall (batch-id uint) (severity uint) (reason (string-ascii 256)) (devices-affected uint))
```
Issues a recall affecting multiple devices in a batch. Administrator only.

**check-recall-status**
```clarity
(check-recall-status (device-id uint))
```
Checks if a device is currently under recall.

**get-recall-details**
```clarity
(get-recall-details (device-id uint))
```
Retrieves complete recall information for a specific device.

**get-batch-recall-info**
```clarity
(get-batch-recall-info (batch-id uint))
```
Retrieves batch recall information.

**get-total-recalls**
```clarity
(get-total-recalls)
```
Returns the total number of recalls issued by the system.

## Validation Rules

### Device Identifiers
- Minimum: 1
- Maximum: 1,000,000

### Batch Identifiers
- Minimum: 1
- Maximum: 1,000,000

### Recall Reasons
- Minimum length: 10 characters
- Maximum length: 256 characters

### Batch Constraints
- Maximum affected batches per recall: 10,000
- Maximum devices per batch: 100,000

### History Tracking
- Maximum history entries per device: 10

## Error Codes

- `u1` - Unauthorized access
- `u2` - Device not found
- `u3` - Status update failed
- `u4` - Invalid lifecycle stage
- `u5` - Invalid certification type
- `u6` - Certification already exists
- `u7` - Device already recalled
- `u8` - Invalid recall severity
- `u9` - Recall not found
- `u10` - Invalid batch ID
- `u11` - Invalid batch count
- `u12` - Invalid reason length

## Access Control

### Administrator Privileges
- Register devices in any lifecycle stage
- Update device status for any device
- Add regulatory authorities
- Issue and resolve recalls
- Revoke any certification

### Device Owners
- Register devices in manufactured stage
- Update status of owned devices

### Regulatory Authorities
- Issue certifications for their approved certification type
- Revoke certifications they issued

## Data Storage

The contract uses the following data structures:

- **registered-devices**: Core device information and lifecycle history
- **issued-certifications**: Certification records with validity status
- **approved-authorities**: Registry of regulatory bodies
- **device-recalls**: Individual device recall information
- **batch-recalls**: Batch recall information

## Security Features

- Principal validation for regulatory authorities
- Access control on all state-changing functions
- Prevention of duplicate certifications
- Validation of all input parameters
- Immutable audit trail through blockchain

## Usage Example

```clarity
;; Register a new device
(contract-call? .device-tracker register-device u12345 u1)

;; Add a regulatory authority
(contract-call? .device-tracker add-regulatory-body 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)

;; Issue FDA certification
(contract-call? .device-tracker add-certification u12345 u1)

;; Update device to testing phase
(contract-call? .device-tracker update-device-status u12345 u2)

;; Check device status
(contract-call? .device-tracker get-device-status u12345)

;; Issue a recall
(contract-call? .device-tracker issue-device-recall u12345 u1 "Critical safety issue detected" u5)
```

## Integration

This smart contract can be integrated with:

- Hospital management systems
- Regulatory compliance platforms
- Medical device manufacturers' systems
- Supply chain tracking solutions
- Maintenance scheduling systems