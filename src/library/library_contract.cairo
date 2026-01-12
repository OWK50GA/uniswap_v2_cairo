#[starknet::contract]
pub mod LibraryContract {
    use starknet::{ClassHash, ContractAddress};
    use crate::library::ilibrary::ILibraryContract;
    use crate::library::library::Library;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {
        
    }

    #[abi(embed_v0)]
    impl LibraryContractImpl of ILibraryContract<ContractState> {
        fn get_salt(
            self: @ContractState, token_a: ContractAddress, token_b: ContractAddress,
        ) -> felt252 {
            Library::get_salt(token_a, token_b)
        }

        fn get_lp_token_metadata(
            self: @ContractState, token_a: ContractAddress, token_b: ContractAddress,
        ) -> (ByteArray, ByteArray) {
            Library::get_lp_token_metadata(token_a, token_b)
        }

        fn compute_hash_on_elements(self: @ContractState, data: Span<felt252>) -> felt252 {
            Library::compute_hash_on_elements(data)
        }

        fn sort_tokens(
            self: @ContractState, token_a: ContractAddress, token_b: ContractAddress,
        ) -> (ContractAddress, ContractAddress) {
            Library::sort_tokens(token_a, token_b)
        }

        fn pair_for(
            self: @ContractState,
            factory: ContractAddress,
            pair_class_hash: ClassHash,
            token_a: ContractAddress,
            token_b: ContractAddress,
        ) -> Option<ContractAddress> {
            Library::pair_for(factory, pair_class_hash, token_a, token_b)
        }

        fn get_reserves(
            self: @ContractState,
            factory: ContractAddress,
            token_a: ContractAddress,
            token_b: ContractAddress,
        ) -> (u256, u256) {
            Library::get_reserves(factory, token_a, token_b)
        }

        fn quote(self: @ContractState, amount_a: u256, reserve_a: u256, reserve_b: u256) -> u256 {
            Library::quote(amount_a, reserve_a, reserve_b)
        }

        fn get_amount_out(
            self: @ContractState, amount_in: u256, reserve_in: u256, reserve_out: u256,
        ) -> u256 {
            Library::get_amount_out(amount_in, reserve_in, reserve_out)
        }

        fn get_amount_in(
            self: @ContractState, amount_out: u256, reserve_in: u256, reserve_out: u256,
        ) -> u256 {
            Library::get_amount_in(amount_out, reserve_in, reserve_out)
        }

        fn get_amounts_out(
            self: @ContractState,
            factory: ContractAddress,
            amount_in: u256,
            path: Array<ContractAddress>,
        ) -> Array<u256> {
            Library::get_amounts_out(factory, amount_in, path)
        }

        fn get_amounts_in(
            self: @ContractState,
            factory: ContractAddress,
            amount_out: u256,
            path: Array<ContractAddress>,
        ) -> Array<u256> {
            Library::get_amounts_in(factory, amount_out, path)
        }
    }
}
