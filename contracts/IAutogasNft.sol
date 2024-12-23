// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAutogasNft {
    struct DelegationDetail {
        address delegatedAddress;
        uint256 sharePercentage;
    }
    
    function getNFTDelegationDetails(address owner, uint256 nftId) external view returns (DelegationDetail[] memory);
    function totalMinted() external view returns (uint256);
}

interface IEnhancedTreasury {
    function generateLightspeed() external;
    function getCoreBalance() external view returns (uint256);
    function getSpeedBalance() external view returns (uint256);
    function receiveCoreTokens(uint256 amount) external;
}

interface ILiquidation {
    function convertSpeedToETH() external;
    function distributeETH() external;
    function updateAirdropList(address[] calldata holders, uint256[] calldata shares) external;
}

interface IDistributionHelper {
    function createSnapshot(address[] calldata holders, uint256[] calldata amounts) external returns (uint256);
    function processSnapshot(uint256 snapshotId) external;
}

interface ISpeedToken {
    function mint(address to, uint256 amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function WETH() external pure returns (address);
}

interface IUniswapV3Quoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}