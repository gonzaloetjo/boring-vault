// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ArbitrumAddresses} from "test/resources/ArbitrumAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Arbitrum/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Arbitrum/DeployLiquidEth.s.sol:DeployLiquidEthScript --with-gas-price 10000000 --evm-version london --broadcast --etherscan-api-key $ARBISCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLiquidEthScript is DeployArcticArchitecture, ArbitrumAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid ETH";
    string public boringVaultSymbol = "liquidETH";
    uint8 public boringVaultDecimals = 18;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("arbitrum");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = false;
        configureDeployment.setupDepositAssets = false;
        configureDeployment.setupWithdrawAssets = false;
        configureDeployment.finishSetup = false;
        configureDeployment.setupTestUser = false;
        configureDeployment.saveDeploymentDetails = false;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WETH);

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiLiquidEthRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiLiquidEthName;
        names.manager = EtherFiLiquidEthManagerName;
        names.accountant = EtherFiLiquidEthAccountantName;
        names.teller = EtherFiLiquidEthTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiLiquidEthDecoderAndSanitizerName;
        names.delayedWithdrawer = EtherFiLiquidEthDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WETH;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1028197560457934080;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiLiquidEthDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup extra deposit assets.
        depositAssets.push(
            DepositAsset({
                asset: WEETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: weETH_ETH_ExchangeRate,
                selector: bytes4(keccak256(abi.encodePacked("latestAnswer()"))),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: WETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        // withdrawAssets.push(
        //     WithdrawAsset({
        //         asset: EETH,
        //         withdrawDelay: 3 days,
        //         completionWindow: 7 days,
        //         withdrawFee: 0,
        //         maxLoss: 0.01e4
        //     })
        // );

        withdrawAssets.push(
            WithdrawAsset({
                asset: WEETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = false;
        bool allowPublicWithdraws = false;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        vm.startBroadcast(privateKey);

        _deploy(
            "Arbitrum/LiquidEthDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            delayedWithdrawFeeAddress,
            allowPublicDeposits,
            allowPublicWithdraws,
            shareLockPeriod,
            dev1Address
        );

        vm.stopBroadcast();
    }
}