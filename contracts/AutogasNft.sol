// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./IAutogasNft.sol";
import "./Autogas2.sol";

/**
 * @title AutoGasBase
 * @dev Base contract with shared functionality for the AutoGas system
 */
abstract contract AutogasNft is ERC1155, Ownable, ReentrancyGuard {
    // Price Feed Interfaces
    AggregatorV3Interface internal ethPriceFeed;
    AggregatorV3Interface internal usdcPriceFeed;

    // Pricing Constants
    uint256 public constant BASE_USD_PRICE = 1 * 10**6; // $1
    uint256 public constant BASE_PRICE = 0.0005 ether; // $1 in wei
    uint256 public constant TEAM_FEE_PERCENTAGE = 5;
    uint256 public constant REFERRAL_DISCOUNT_PERCENTAGE = 5;
    uint256 public constant BULK_DISCOUNT_PERCENTAGE = 10;
    uint256 public constant BULK_DISCOUNT_THRESHOLD = 100;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MIN_MINT = 1;
    uint256 public constant MAX_MINT_PER_TX = 100;
    uint256 public constant MIN_ETH_AMOUNT = 0.0005 ether; // Minimum for 1 NFT
    uint256 public constant MIN_USDC_AMOUNT = 1 * 10**6;   // Minimum 1 USDC
    uint256 public constant MIN_CORE_AMOUNT = 1 * 10**18;

    // Token and Contract Addresses
    IERC20 public coreToken;
    ISpeedToken public speedToken;
    IUniswapV2Router02 public uniswapRouter;
    IERC20 public usdcToken;
    IUniswapV3Quoter public v3Quoter;
    IEnhancedTreasury public treasury;
    ILiquidation public liquidation;
    

    // Dynamic Pricing Variables
    uint256 public mintPriceETH;
    uint256 public mintPriceCore;
    uint256 public lastPriceUpdateTimestamp;

    // Constant Pool and Conversion Addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 public constant POOL_FEE = 3000;
    address public teamWallet;

    // NFT Tracking
    uint256 public constant NFT_ID = 1;
    uint256 public totalMinted;

    // Enums
    enum PaymentType {
        ETH,
        USDC,
        CORE
    }

    // Events
    event PricesUpdated(uint256 ethPrice, uint256 corePrice);
    event TreasuryUpdated(address newTreasury);
    event LiquidationUpdated(address newLiquidation);

    constructor(
        string memory uri_,
        address _ethPriceFeed,
        address _usdcPriceFeed,
        address _coreToken,
        address _speedToken,
        address _uniswapRouter,
        address _v3Quoter,
        address _treasury,
        address _liquidation,
        address _teamWallet 
    ) ERC1155(uri_) Ownable(msg.sender) {
        require(_ethPriceFeed != address(0), "Invalid ETH price feed");
    require(_usdcPriceFeed != address(0), "Invalid USDC price feed");
    require(_coreToken != address(0), "Invalid CORE token");
    require(_speedToken != address(0), "Invalid SPEED token");
    require(_uniswapRouter != address(0), "Invalid Uniswap router");
    require(_v3Quoter != address(0), "Invalid V3 quoter");
    require(_treasury != address(0), "Invalid treasury");
    require(_liquidation != address(0), "Invalid liquidation");
    require(_teamWallet != address(0), "Invalid team wallet");

        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
        usdcPriceFeed = AggregatorV3Interface(_usdcPriceFeed);
        coreToken = IERC20(_coreToken);
        speedToken = ISpeedToken(_speedToken);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        v3Quoter = IUniswapV3Quoter(_v3Quoter);
        treasury = IEnhancedTreasury(_treasury);
        liquidation = ILiquidation(_liquidation);
        teamWallet = _teamWallet;
        
        // updateMintPrices();
    }

    // Admin functions
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = IEnhancedTreasury(_treasury);
        emit TreasuryUpdated(_treasury);
    }

    function setLiquidation(address _liquidation) external onlyOwner {
        require(_liquidation != address(0), "Invalid liquidation");
        liquidation = ILiquidation(_liquidation);
        emit LiquidationUpdated(_liquidation);
    }

    // Price functions
    function updateMintPrices() public {
        (int256 ethPrice,) = getPriceWithDecimals(ethPriceFeed);
        mintPriceETH = uint256(BASE_USD_PRICE * 10**18 / uint256(ethPrice));
        
        lastPriceUpdateTimestamp = block.timestamp;
        emit PricesUpdated(mintPriceETH, mintPriceCore);
    }

    function getPriceWithDecimals(AggregatorV3Interface priceFeed) public view returns (int256, uint8) {
        (,int256 price,,uint256 timeStamp,) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Invalid price feed data");
        uint8 decimals = priceFeed.decimals();
        return (price, decimals);
    }

    // Internal utility functions
    function _validatePrice(uint256 amount, PaymentType paymentType) internal view returns (uint256) {
        if(paymentType == PaymentType.ETH) {
            return amount * mintPriceETH;
        } else if(paymentType == PaymentType.USDC) {
            return amount * BASE_USD_PRICE;
        } else {
            return amount * mintPriceCore;
        }
    }

    // Abstract functions to be implemented by derived contracts
    function mintNFT(
        uint256 quantity,
        PaymentType paymentType,
        string memory referralCode
    ) external virtual payable;
    function calculateMintPrice(uint256 quantity, string memory referralCode) external view virtual returns (uint256);
    function getEthPrice() public view returns (int256) {
        (,int256 price,,,) = ethPriceFeed.latestRoundData();
        return price;
    }
    function getUsdcPrice() public view returns (int256) {
        (,int256 price,,,) = usdcPriceFeed.latestRoundData();
        return price;
    }
}