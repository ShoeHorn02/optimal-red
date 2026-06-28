# Optimal Red

Apple Health tracking platform for Watch, iPhone, Mac, and Web.

## Quick Start

### Prerequisites
- Xcode 15+
- Node.js 18+
- npm workspaces support
- Apple Developer account

### Setup

```bash
git clone git@github.com:ShoeHorn02/optimal-red.git
cd optimal-red

# Install dependencies
npm install
```

### Packages

- **@optimal-red/shared** - Shared types and utilities
- **@optimal-red/watchos** - watchOS companion app
- **@optimal-red/ios** - iPhone app
- **@optimal-red/macos** - macOS app (Phase 2)
- **@optimal-red/backend** - Next.js backend API

### Development

```bash
# Backend development
npm run dev --workspace=packages/backend

# Build shared types
npm run build --workspace=packages/shared
```

### Xcode Projects

Watch and iPhone apps are native Xcode projects:
- `packages/watchos/OptimalRedWatch/` - Open in Xcode
- `packages/ios/OptimalRed/` - Open in Xcode

## Architecture

See [CLAUDE.md](./CLAUDE.md) for complete architecture and phasing details.

## Status

**Current Phase**: 0 (MVP) - Initialize monorepo & create Watch + iPhone apps

See [CLAUDE.md](./CLAUDE.md) for detailed status and next steps.

## License

Private repository
