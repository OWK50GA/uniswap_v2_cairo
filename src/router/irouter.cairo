use starknet::ContractAddress;

#[starknet::interface]
pub trait IRouter<TContractState> {
    fn add_liquidity(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256, u256); // amount a, amount b, liquidity
    fn remove_liquidity(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        liquidity: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(
        ref self: TContractState,
        amount_in: u256,
        amount_out_min: u256,
        path: Array<ContractAddress>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;
    fn swap_tokens_for_exact_tokens(
        ref self: TContractState,
        amount_out: u256,
        amount_in_max: u256,
        path: Array<ContractAddress>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;


    fn quote(
        self: @TContractState, amount_a: u256, reserve_a: u256, reserve_b: u256,
    ) -> u256; // amount_b
    fn get_amount_out(
        self: @TContractState, amount_in: u256, reserve_in: u256, reserve_out: u256,
    ) -> u256; // amount_out
    fn get_amount_in(
        self: @TContractState, amount_out: u256, reserve_in: u256, reserve_out: u256,
    ) -> u256; // amount_in
    fn get_amounts_out(
        self: @TContractState, amount_in: u256, path: Array<ContractAddress>,
    ) -> Array<u256>; // amounts
    fn get_amounts_in(
        self: @TContractState, amount_out: u256, path: Array<ContractAddress>,
    ) -> Array<u256>; // amounts
}
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

// address tokenA,

// address tokenB,

// uint amountADesired,

// uint amountBDesired,

// uint amountAMin,

// uint amountBMin,

// address to,

// uint deadline

// ) external returns (uint amountA, uint amountB, uint liquidity);

// function addLiquidityETH(

// address token,

// uint amountTokenDesired,

// uint amountTokenMin,

// uint amountETHMin,

// address to,

// uint deadline

// ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

// function removeLiquidity(

// address tokenA,

// address tokenB,

// uint liquidity,

// uint amountAMin,

// uint amountBMin,

// address to,

// uint deadline

// ) external returns (uint amountA, uint amountB);

// function removeLiquidityWithPermit(

// address tokenA,

// address tokenB,

// uint liquidity,

// uint amountAMin,

// uint amountBMin,

// address to,

// uint deadline,

// bool approveMax, uint8 v, bytes32 r, bytes32 s

// ) external returns (uint amountA, uint amountB);

// function swapExactTokensForTokens(

// uint amountIn,

// uint amountOutMin,

// address[] calldata path,

// address to,

// uint deadline

// ) external returns (uint[] memory amounts);

// function swapTokensForExactTokens(

// uint amountOut,

// uint amountInMax,

// address[] calldata path,

// address to,

// uint deadline

// ) external returns (uint[] memory amounts);

// function swapExactTokensForTokensSupportingFeeOnTransferTokens(

// uint amountIn,

// uint amountOutMin,

// address[] calldata path,

// address to,

// uint deadline

// ) external;

