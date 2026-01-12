use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait ILibraryContract<TContractState> {
    fn get_salt(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> felt252;

    fn get_lp_token_metadata(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> (ByteArray, ByteArray);

    fn compute_hash_on_elements(self: @TContractState, data: Span<felt252>) -> felt252;

    fn sort_tokens(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> (ContractAddress, ContractAddress);

    fn pair_for(
        self: @TContractState,
        factory: ContractAddress,
        pair_class_hash: ClassHash,
        token_a: ContractAddress,
        token_b: ContractAddress,
    ) -> Option<ContractAddress>;

    fn get_reserves(
        self: @TContractState,
        factory: ContractAddress,
        token_a: ContractAddress,
        token_b: ContractAddress,
    ) -> (u256, u256);

    fn quote(self: @TContractState, amount_a: u256, reserve_a: u256, reserve_b: u256) -> u256;

    fn get_amount_out(
        self: @TContractState, amount_in: u256, reserve_in: u256, reserve_out: u256,
    ) -> u256;

    fn get_amount_in(
        self: @TContractState, amount_out: u256, reserve_in: u256, reserve_out: u256,
    ) -> u256;

    fn get_amounts_out(
        self: @TContractState,
        factory: ContractAddress,
        amount_in: u256,
        path: Array<ContractAddress>,
    ) -> Array<u256>;

    fn get_amounts_in(
        self: @TContractState,
        factory: ContractAddress,
        amount_out: u256,
        path: Array<ContractAddress>,
    ) -> Array<u256>;
}
