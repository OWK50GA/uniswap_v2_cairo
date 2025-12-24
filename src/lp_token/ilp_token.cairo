use starknet::ContractAddress;

#[starknet::interface]
pub trait ILPToken<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, sender: ContractAddress, amount: u256);
    fn get_total_supply(self: @TContractState) -> u256;
}
