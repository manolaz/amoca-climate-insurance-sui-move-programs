# AMOCA Climate Insurance

A decentralized parametric climate insurance protocol built on Sui. AMOCA provides automated climate risk protection through verifiable environmental data from oracles, enabling instant payouts when predefined climate thresholds are met.

## 🌍 Overview

Climate change poses increasing risks to agriculture, property, and livelihoods worldwide. Traditional insurance is slow, expensive, and often inaccessible to those who need it most. AMOCA Climate Insurance solves this through:

- **Parametric Triggers**: Automatic payouts based on objective climate data (rainfall, temperature, wind speed, etc.)
- **Oracle Integration**: Real-time data from satellites, weather stations, and IoT sensors
- **Instant Settlements**: Smart contract-based payouts without lengthy claims processes
- **Global Accessibility**: Decentralized protocol accessible to anyone worldwide
- **Transparent Operations**: All policies, triggers, and payouts are verifiable on-chain

## 🏗️ Architecture

### Core Components

1. **Climate Policies**: Smart contracts defining coverage terms, geographic bounds, and trigger conditions
2. **Oracle Network**: Decentralized data providers submitting verified climate information
3. **Risk Pool**: Automated treasury managing premiums and payouts
4. **Trigger Engine**: Parametric evaluation system for automated claim processing

### Supported Climate Risks

- 🌧️ **Drought Protection**: Based on rainfall measurements
- 🌊 **Flood Insurance**: Water level and precipitation monitoring  
- 🌪️ **Hurricane Coverage**: Wind speed and pressure tracking
- 🌾 **Agricultural Climate**: Multi-parameter crop protection
- 🔥 **Wildfire Protection**: Fire proximity and weather conditions
- 🌊 **Sea Level Rise**: Coastal monitoring and protection
- 🌡️ **Extreme Temperature**: Heat/cold wave protection

## 📋 Features

### For Policyholders

- Create customized climate insurance policies
- Set geographic coverage areas and risk parameters
- Deposit premiums to activate coverage
- Receive automatic payouts when triggers are met
- Monitor policy status and climate data in real-time

### For Oracle Providers

- Submit verified climate data from multiple sources
- Build reputation through consistent, accurate reporting
- Earn rewards for providing high-quality data
- Participate in decentralized consensus mechanisms

### For Administrators

- Pause/unpause program operations
- Monitor global insurance metrics
- Manage oracle provider registrations
- Oversee risk pool operations

## 🚀 Getting Started

### Prerequisites

- [Rust](https://rustlang.org/tools/install)
- [Sui CLI](https://docs.Sui.com/cli/install-Sui-cli-tools)
- [Node.js](https://nodejs.org/) and [Yarn](https://yarnpkg.com/)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/your-org/amoca-climate-insurance.git
   cd amoca-climate-insurance
   ```

2. **Install dependencies**

   ```bash
   yarn install
   ```

3. **Build the program**

   ```bash
   sui move build
   ```

4. **Deploy to localnet**

   ```bash
   sui client publish
   ```

5. **Run tests**

   ```bash
   sui move test
   ```

### Configuration

Update `Move.toml` with your desired network settings:

```toml
[package]
name = "amoca_insurance_package"
version = "0.1.0"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "devnet" }

[addresses]
amoca_insurance_package = "0x0"
```

## 📚 Program Instructions

### Core Instructions

#### `initialize`

Initialize the global program state and risk pool.

**Parameters:**

- `authority: address` - Program authority

**Context:**

- `ctx: &mut TxContext` - Transaction context

#### `create_climate_policy`

Create a new parametric climate insurance policy.

**Parameters:**

- `state: &mut GlobalState` - Global state object
- `owner: address` - Policy owner
- `coverage_amount: u64` - Maximum payout amount
- `premium_amount: u64` - Required premium payment
- `end_timestamp: u64` - Policy expiration time
- `trigger_rainfall: u64` - Rainfall trigger threshold
- `trigger_temperature: u64` - Temperature trigger threshold
- `measurement_period: u64` - Measurement period
- `minimum_duration: u64` - Minimum duration for trigger

**Context:**

- `ctx: &mut TxContext` - Transaction context

#### `deposit_premium`

Deposit premium to activate a climate insurance policy.

**Parameters:**

- `state: &mut GlobalState` - Global state object
- `policy: &mut ClimatePolicy` - Policy object
- `amount: u64` - Premium amount to deposit

**Context:**

- `ctx: &mut TxContext` - Transaction context

#### `submit_climate_data`

Submit verified climate data from oracle sources.

**Parameters:**

- `state: &GlobalState` - Global state object
- `policy: &mut ClimatePolicy` - Policy object
- `value: u64` - Climate data value
- `timestamp: u64` - Data timestamp
- `confidence: u8` - Confidence level

**Context:**

- `ctx: &mut TxContext` - Transaction context

#### `evaluate_climate_trigger`

Evaluate policy trigger conditions against current climate data.

**Parameters:**

- `state: &mut GlobalState` - Global state object
- `policy: &mut ClimatePolicy` - Policy object
- `rainfall_value: u64` - Current rainfall value
- `temperature_value: u64` - Current temperature value
- `measurement_duration: u64` - Duration of measurement
- `timestamp: u64` - Evaluation timestamp

**Context:**

- `ctx: &mut TxContext` - Transaction context

#### `execute_climate_payout`

Execute automatic payout when trigger conditions are met.

**Parameters:**

- `state: &mut GlobalState` - Global state object
- `policy: &mut ClimatePolicy` - Policy object

**Context:**

- `ctx: &mut TxContext` - Transaction context

### Admin Instructions

#### `pause_program` / `unpause_program`

Emergency controls for program operations.

**Parameters:**

- `state: &mut GlobalState` - Global state object

**Context:**

- `ctx: &mut TxContext` - Transaction context

## 🧪 Testing

The test suite covers all major functionality:

```bash
# Run all tests
sui move test
```

### Test Coverage

- ✅ Program initialization
- ✅ Policy creation and validation
- ✅ Premium deposits and token transfers
- ✅ Oracle data submission
- ✅ Trigger evaluation logic
- ✅ Payout execution
- ✅ Admin controls
- ✅ Security and edge cases

## 🏛️ Program Data Structures

### `GlobalState`

```move
public struct GlobalState has key, store {
    id: object::UID,
    authority: address,
    paused: bool,
    total_policies: u64,
    total_premiums_collected: u64,
    total_payouts_released: u64,
    risk_pool_balance: u64,
}
```

### `ClimatePolicy`

```move
public struct ClimatePolicy has key, store {
    id: object::UID,
    owner: address,
    status: u8,
    coverage_amount: u64,
    premium_amount: u64,
    deposited_premium: u64,
    pending_payout: u64,
    trigger_rainfall: u64,
    trigger_temperature: u64,
    measurement_period: u64,
    minimum_duration: u64,
    end_timestamp: u64,
    last_data_timestamp: u64,
    last_data_value: u64,
    last_data_confidence: u8,
}
```

## 🔒 Security Features

### Access Controls

- Program authority for admin operations
- Policy owner restrictions for policy management
- Oracle provider authentication for data submission
- Object-based ownership validation

### Validation Checks

- Coverage and premium amount validation
- Timestamp validation (policy expiration)
- Confidence level thresholds for oracle data
- Premium deposit validation
- Math overflow protection (using u64 limits)

### Emergency Controls

- Program pause/unpause functionality
- Administrative override capabilities
- Oracle data validation
- Risk pool balance checks

## 🌐 Oracle Integration

### Supported Oracle Types

- **Chainlink Weather**: Decentralized weather data
- **Pyth Satellite**: High-frequency satellite data
- **NASA MODIS**: Earth observation data
- **Weather Stations**: Ground-based measurements
- **IoT Sensors**: Real-time environmental monitoring
- **Switchboard Network**: Cross-chain oracle data

### Data Quality Assurance

- Multi-oracle consensus requirements
- Confidence level scoring (0-100%)
- Reputation-based oracle weighting
- Cryptographic verification hashes
- Temporal validation (data recency checks)

## 📊 Economics

### Premium Calculation

Premiums are calculated based on:

- Historical climate data for the region
- Coverage amount and duration
- Risk assessment algorithms
- Oracle data quality and availability
- Market conditions and pool reserves

### Payout Formulas

- **Linear Scale**: Proportional payout based on deviation from threshold
- **Step Function**: Fixed payouts at specific trigger levels  
- **Exponential**: Accelerating payouts for extreme events
- **Composite**: Multi-parameter weighted calculations

### Risk Pool Management

- Automated premium collection
- Dynamic reserve requirements
- Diversification across risk types and geographies
- Surplus distribution mechanisms

## 🚨 Error Codes

Common error codes and their meanings:

| Code | Error | Description |
|------|-------|-------------|
| 6000 | `InvalidCoverageAmount` | Coverage amount must be greater than 0 |
| 6001 | `InvalidPolicyDuration` | End timestamp must be in the future |
| 6002 | `InvalidPremiumAmount` | Premium amount must be greater than 0 |
| 6003 | `InvalidGeographicBounds` | Latitude/longitude values out of range |
| 6004 | `PolicyAlreadyActive` | Cannot modify active policy |
| 6005 | `InsufficientPremium` | Premium payment below required amount |
| 6006 | `OracleNotAuthorized` | Oracle provider not authorized |
| 6007 | `InvalidOracleData` | Invalid or malformed oracle data |
| 6008 | `StaleOracleData` | Oracle data too old to be valid |
| 6009 | `LowConfidenceData` | Oracle confidence level below threshold |
| 6010 | `PolicyNotActive` | Policy must be active for operation |
| 6011 | `PolicyExpired` | Policy has passed expiration date |
| 6012 | `TriggerNotMet` | Trigger conditions not satisfied |
| 6013 | `InvalidPayoutAmount` | Payout amount invalid or excessive |
| 6014 | `MathOverflow` | Arithmetic operation overflow |
| 6015 | `Unauthorized` | Insufficient permissions |
| 6016 | `ProgramPaused` | Program operations are paused |

## 🛣️ Roadmap

### Phase 1: Core Infrastructure ✅

- [x] Basic policy creation and management
- [x] Premium deposits and risk pool
- [x] Oracle data submission
- [x] Simple trigger evaluation
- [x] Manual payout execution

### Phase 2: Advanced Features 🚧

- [ ] Multi-oracle consensus mechanisms
- [ ] Advanced payout calculations
- [ ] Automated keeper network
- [ ] Policy transferability
- [ ] Staking and governance

### Phase 3: Ecosystem Expansion 📋

- [ ] Mobile applications
- [ ] Web dashboard
- [ ] API integrations
- [ ] Partner oracle networks
- [ ] Cross-chain compatibility

### Phase 4: Enterprise Features 📋

- [ ] Institutional risk pools
- [ ] Reinsurance protocols
- [ ] Regulatory compliance tools
- [ ] Enterprise APIs
- [ ] White-label solutions

## 🤝 Contributing

We welcome contributions from developers, climate scientists, insurance experts, and community members!

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

### Areas for Contribution

- Oracle integrations and data sources
- Advanced trigger logic and calculations
- User interface and experience improvements
- Testing and security audits
- Documentation and tutorials

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Sui Labs for the robust blockchain platform
- Move programming language for smart contract development
- Climate data providers and oracle networks
- Insurance industry experts and advisors
- Open source community contributors

## 📞 Support

- **Documentation**: [docs.amoca.climate](https://docs.amoca.climate)
- **Discord**: [discord.gg/amoca](https://discord.gg/amoca)
- **Twitter**: [@AmocaClimate](https://twitter.com/AmocaClimate)
- **Email**: [support@amoca.climate](mailto:support@amoca.climate)

---

**Disclaimer**: This software is experimental and under development. Use at your own risk. Climate insurance involves financial instruments and regulatory considerations that vary by jurisdiction. Please consult with legal and financial advisors before deployment in production environments.
