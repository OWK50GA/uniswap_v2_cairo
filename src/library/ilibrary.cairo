use starknet::ContractAddress;

#[starknet::interface]
pub trait ILibrary<TContractState> {
    fn sort_tokens(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> (ContractAddress, ContractAddress); // token0, token1
    fn pair_for(
        self: @TContractState,
        factory: ContractAddress,
        pair_class_hash: felt252,
        token_a: ContractAddress,
        token_b: ContractAddress,
    ) -> ContractAddress; //pair contract address
    fn get_reserves(
        self: @TContractState,
        factory: ContractAddress,
        token_a: ContractAddress,
        token_b: ContractAddress,
    ) -> (u256, u256); // reserve_a, reserve_b
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
        self: @TContractState, factory: ContractAddress, amount_in: u256, path: Array<ContractAddress>,
    ) -> Array<u256>;
    fn get_amounts_in(
        self: @TContractState,
        factory: ContractAddress,
        amount_out: u256,
        path: Array<ContractAddress>,
    ) -> Array<u256>;
}
// Functions to be in library:

// function sortTokens(address tokenA, address tokenB) internal pure returns (address token0,
// address token1);
// function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address
// pair);
// function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint
// reserveA, uint reserveB);
// function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB);
// function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint
// amountOut);
// function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint
// amountIn);
// function getAmountsOut(uint amountIn, address[] memory path) internal view returns (uint[] memory
// amounts);
// function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view
// returns (uint[] memory amounts);

// Explainer for these functions in
// https://docs.uniswap.org/contracts/v2/reference/smart-contracts/library


