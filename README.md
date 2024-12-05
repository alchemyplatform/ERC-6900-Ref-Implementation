# ERC-6900 Reference Implementation

[![tg_badge]][tg_link]

[tg_badge]: https://img.shields.io/endpoint?color=neon&logo=telegram&label=chat&url=https://mogyo.ro/quart-apis/tgmembercount?chat_id=modular_account_standards
[tg_link]: https://t.me/modular_account_standards

Reference implementation for [ERC-6900](https://eips.ethereum.org/EIPS/eip-6900).

This repository contains the contracts below which are compliant with the latest version of ERC-6900. They are not optimized in both deployments and execution. We’ve explicitly removed some optimizations in favor of clarity.

> [!IMPORTANT]  
> Unless otherwise stated, these contracts are not audited and SHOULD NOT be used in production.

- Reference account implementations
  - [ReferenceModularAccount](src/account/ReferenceModularAccount.sol): A simple ERC-6900 compatible account.
  - [SemiModularAccount](src/account/SemiModularAccount.sol): An ERC-6900 account that includes a fallback validation mechanism.
- Factory
  - [AccountFactory](src/account/AccountFactory.sol): Deploys both account types.
- ERC-6900 interfaces: [src/interfaces](src/interfaces/)
- Helpers
  - [CollectReturnData](src/helpers/CollectReturnData.sol)
  - [Constants](src/helpers/Constants.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
  - [EmptyCalldataSlice](src/helpers/EmptyCalldataSlice.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
  - [ValidationResHelpers](src/helpers/ValidationResHelpers.sol)
- Libraries
  - [HookConfigLib](src/libraries/HookConfigLib.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
  - [KnownSelectorsLib](src/libraries/KnownSelectorsLib.sol)
  - [ModuleEntityLib](src/libraries/ModuleEntityLib.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
  - [ModuleStorageLib](src/libraries/ModuleStorageLib.sol)
  - [SparseCalldataSegmentLib](src/libraries/SparseCalldataSegmentLib.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
  - [ValidationConfigLib](src/libraries/ValidationConfigLib.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
- ERC-6900 compatible modules
  - Validation modules:
    - [SingleSignerValidationModule](src/modules/validation/SingleSignerValidationModule.sol): Enables validation for a single signer (EOA or contract).
  - Permission-enforcing hook modules:
    - [AllowlistModule](src/modules/permissions/AllowlistModule.sol): Enforces address/selector allowlists.
    - [ERC20TokenLimitModule](src/modules/permissions/ERC20TokenLimitModule.sol): Enforces ERC-20 spend limits.
    - [NativeTokenLimitModule](src/modules/permissions/NativeTokenLimitModule.sol): Enforces native token spend limits.
  - Execution modules:
    - [TokenReceiverModule](src/modules/TokenReceiverModule.sol): Allows the account to receive ERC-721 and ERC-1155 tokens.
- Module utilities
  - [ModuleEIP712](src/modules/ModuleEIP712.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))
  - [ReplaySafeWrapper](src/modules/ReplaySafeWrapper.sol): ✅ Audited ([reports](https://github.com/alchemyplatform/modular-account/tree/develop/audits))

## Development

Anyone is welcome to submit feedback and/or PRs to improve the code. For standard improvement proposals and discussions, join us at https://github.com/erc6900/resources/issues or [Ethereum Magicians](https://ethereum-magicians.org/t/erc-6900-modular-smart-contract-accounts-and-plugins/13885).

## Testing

The default Foundry profile can be used to compile (without IR) and test the entire project. The default profile should be used when generating coverage and debugging.

```bash
forge build
forge test -vvv
```

Since IR compilation generates different bytecode, it's useful to test against the contracts compiled via IR. Since compiling the entire project (including the test suite) takes a long time, special profiles can be used to precompile just the source contracts, and have the tests deploy the relevant contracts using those artifacts.

```bash
FOUNDRY_PROFILE=optimized-build forge build
FOUNDRY_PROFILE=optimized-test forge test -vvv
```

### Integration testing

The reference implementation provides a sample factory and deploy script for the factory, account implementation, and the demo validation module `SingleSignerValidationModule`. This is not audited nor intended for production use. Limitations set by the GPLv3 license apply.

To run this script, provide appropriate values in a `.env` file based on the `.env.example` template, then run:

```bash
forge script script/Deploy.s.sol <wallet options> -r <rpc_url> --broadcast
```

Where `<wallet_options>` specifies a way to sign the deployment transaction (see [here](https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw)) and `<rpc_url>` specifies an RPC for the network you are deploying on.
