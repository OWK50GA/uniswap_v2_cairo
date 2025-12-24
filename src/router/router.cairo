// Explainer for these functions here
// https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02

// function factory() external pure returns (address);
// function getAmountOut
// function getAmountIn
// function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory
// amounts);
// function getAmountsIn(uint amountOut, address[] memory path) public view returns (uint[] memory
// amounts);

// State-changing functions

// function addLiquidity(
//   address tokenA,
//   address tokenB,
//   uint amountADesired,
//   uint amountBDesired,
//   uint amountAMin,
//   uint amountBMin,
//   address to,
//   uint deadline
// ) external returns (uint amountA, uint amountB, uint liquidity);

// function addLiquidityETH(
//   address token,
//   uint amountTokenDesired,
//   uint amountTokenMin,
//   uint amountETHMin,
//   address to,
//   uint deadline
// ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

// function removeLiquidity(
//   address tokenA,
//   address tokenB,
//   uint liquidity,
//   uint amountAMin,
//   uint amountBMin,
//   address to,
//   uint deadline
// ) external returns (uint amountA, uint amountB);

// function removeLiquidityWithPermit(
//   address tokenA,
//   address tokenB,
//   uint liquidity,
//   uint amountAMin,
//   uint amountBMin,
//   address to,
//   uint deadline,
//   bool approveMax, uint8 v, bytes32 r, bytes32 s
// ) external returns (uint amountA, uint amountB);

// function swapExactTokensForTokens(
//   uint amountIn,
//   uint amountOutMin,
//   address[] calldata path,
//   address to,
//   uint deadline
// ) external returns (uint[] memory amounts);

// function swapTokensForExactTokens(
//   uint amountOut,
//   uint amountInMax,
//   address[] calldata path,
//   address to,
//   uint deadline
// ) external returns (uint[] memory amounts);

// function swapExactTokensForTokensSupportingFeeOnTransferTokens(
//   uint amountIn,
//   uint amountOutMin,
//   address[] calldata path,
//   address to,
//   uint deadline
// ) external;


