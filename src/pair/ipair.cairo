use starknet::ContractAddress;

#[starknet::interface]
pub trait IPair<T> {
    fn mint(ref self: T, to: ContractAddress);
    fn burn(ref self: T, to: ContractAddress);
    fn swap(ref self: T, amount0_out: u256, amount1_out: u256, to: ContractAddress);
    fn sync(ref self: T);
    fn get_reserves_pub(self: @T) -> (u256, u256, u64);
    fn skim(ref self: T, to: ContractAddress);
}
