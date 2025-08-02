# Health Record Ownership NFTs
Smart contract for managing patient health records as NFTs on the Stacks blockchain.

## 🎯 Features

- Mint NFTs representing encrypted health records
- Grant/revoke access to specific providers
- Time-based access control
- Record activation/deactivation
- Provider authorization system

## 💻 Usage

### For Patients

1. `mint-health-record`: Create a new health record NFT
2. `grant-access`: Give providers access to records
3. `revoke-access`: Remove provider access
4. `transfer`: Transfer record ownership

### For Providers

1. `access-record`: View authorized records
2. `get-record-metadata`: View record details

### For Administrators

1. `authorize-provider`: Add approved providers
2. `revoke-provider`: Remove provider access
3. `set-contract-owner`: Update contract ownership

## 🔐 Security

- Records are stored as encrypted hashes
- Access control through permission mapping
- Time-based access expiration
- Only record owners can grant access

## 🚀 Getting Started

Deploy using Clarinet:
```bash
clarinet deploy
```

## 📝 License

MIT
```
