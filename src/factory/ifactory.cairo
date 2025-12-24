use starknet::ContractAddress;

#[starknet::interface]
pub trait IFactory<T> {
    fn all_pairs_length(self: @T) -> u64;
    fn create_pair(
        ref self: T, tokenA: ContractAddress, tokenB: ContractAddress,
    ) -> ContractAddress;
    fn get_pair(self: @T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
    fn set_fee_to(ref self: T, fee_to: ContractAddress);
    fn set_new_owner(ref self: T, new_owner: ContractAddress); // same as set_fee_to_setter
    fn get_fee_to(self: @T) -> ContractAddress;
}
