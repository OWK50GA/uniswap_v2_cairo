#[starknet::contract]
pub mod Router {
    use crate::pair::ipair::{IPairDispatcher, IPairDispatcherTrait};
    use crate::router::irouter::IRouter;
    use core::num::traits::Zero;
    use crate::library::library::Library;
    use crate::factory::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
    use starknet::storage::{StoragePointerWriteAccess, StoragePointerReadAccess};
    use starknet::{ContractAddress, get_block_timestamp, ClassHash, get_caller_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    pub struct Storage {
        pub factory: ContractAddress,
        pub pair_class_hash: ClassHash,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[constructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        self.factory.write(factory);
    }

    #[generate_trait]
    impl InternalFunctions of InternalTrait {
        fn ensure_deadline(self: @ContractState, deadline: u64) {
            assert(deadline <= get_block_timestamp(), 'Expired');
        }

        fn _add_liquidity(
            ref self: ContractState,
            token_a: ContractAddress,
            token_b: ContractAddress,
            amount_a_desired: u256,
            amount_b_desired: u256,
            amount_a_min: u256,
            amount_b_min: u256,
        ) -> (u256, u256) {
            let factory_address = self.factory.read();
            let factory = IFactoryDispatcher { contract_address: factory_address };
            let (token_0, token_1) = Library::sort_tokens(token_a, token_b);
            let mut pair = factory.get_pair(token_0, token_1);

            if (pair.is_zero()) {
                pair = factory.create_pair(token_0, token_1);
            }
            let (reserve_a, reserve_b) = Library::get_reserves(factory_address, token_0, token_1);

            let (mut amount_a, mut amount_b) = (0, 0);

            if reserve_a == 0 && reserve_b == 0 {
                amount_a = amount_a_desired;
                amount_b = amount_b_desired;
            } else {
                let amount_b_optimal = Library::quote(amount_a_desired, reserve_a, reserve_b);
                if amount_b_optimal <= amount_b_desired {
                    assert(amount_b_optimal >= amount_b_min, 'INSUFFICIENT AMOUNT B');
                    amount_a = amount_a_desired;
                    amount_b = amount_b_optimal;
                } else {
                    let amount_a_optimal = Library::quote(amount_b_desired, reserve_b, reserve_a);
                    assert(amount_a_optimal <= amount_a_desired, 'EXCESS AMOUNT A');
                    assert(amount_a_optimal >= amount_a_min, 'INSUFFICIENT AMOUNT A');
                    amount_a = amount_a_optimal;
                    amount_b = amount_b_desired;
                }
            }

            (amount_a, amount_b)
        }

        fn _swap(ref self: ContractState, amounts: Span<u256>, path: Span<ContractAddress>, to: ContractAddress) {
            let factory = self.factory.read();
            let pair_class_hash = self.pair_class_hash.read();

            for i in 0..(path.len() - 1) {
                let (input, output) = (*path.at(i), *path.at(i + 1));
                let (token_0, _) = Library::sort_tokens(input, output);
                let amount_out = *amounts.at(i + 1);
                let (amount_0_out, amount_1_out) = if input == token_0 { (0, amount_out) } else { (amount_out, 0) };

                let _to = if i < path.len() - 2 { Library::pair_for(factory, pair_class_hash, output, *path.at(i + 2)).unwrap() } else { to };
                let pair_dispatcher = IPairDispatcher { contract_address: Library::pair_for(factory, pair_class_hash, input, output).unwrap() };
                pair_dispatcher.swap(amount_0_out, amount_1_out, _to);
            }
        }
    }

    #[abi(embed_v0)]
    pub impl RouterImpl of IRouter<ContractState> {
        fn add_liquidity(
            ref self: ContractState,
            token_a: ContractAddress,
            token_b: ContractAddress,
            amount_a_desired: u256,
            amount_b_desired: u256,
            amount_a_min: u256,
            amount_b_min: u256,
            to: ContractAddress,
            deadline: u64,
        ) -> (u256, u256, u256) {
            self.ensure_deadline(deadline);
            let (token_0, token_1) = Library::sort_tokens(token_a, token_b);
            let factory = self.factory.read();
            let caller = get_caller_address();
            let (amount_0, amount_1) = self._add_liquidity(token_0, token_1, amount_a_desired, amount_b_desired, amount_a_min, amount_b_min);

            let pair = Library::pair_for(factory, self.pair_class_hash.read(), token_0, token_1).unwrap();

            let (token_0_dispatcher, token_1_dispatcher) = (
                IERC20Dispatcher { contract_address: token_0 }, IERC20Dispatcher { contract_address: token_1 }
            );
            token_0_dispatcher.transfer_from(caller, pair, amount_0);
            token_1_dispatcher.transfer_from(caller, pair, amount_1);
            
            let pair_dispatcher = IPairDispatcher { contract_address: pair };
            let liquidity = pair_dispatcher.mint(to);

            (amount_0, amount_1, liquidity)
        } // amount a, amount b, liquidity

        fn remove_liquidity(
            ref self: ContractState,
            token_a: ContractAddress,
            token_b: ContractAddress,
            liquidity: u256,
            amount_a_min: u256,
            amount_b_min: u256,
            to: ContractAddress,
            deadline: u64,
        ) -> (u256, u256) {
            self.ensure_deadline(deadline);
            let factory = self.factory.read();
            let pair_class_hash = self.pair_class_hash.read();
            let caller = get_caller_address();
            let (token_0, token_1) = Library::sort_tokens(token_a, token_b);
            let pair = Library::pair_for(factory, pair_class_hash, token_0, token_1).unwrap();

            let pair_token_dispatcher = IERC20Dispatcher { contract_address: pair };
            pair_token_dispatcher.transfer_from(caller, pair, liquidity);

            let pair_dispatcher = IPairDispatcher { contract_address: pair };

            let (amount_0, amount_1) = pair_dispatcher.burn(to);
            let (mut amount_a, amount_b) = if token_a == token_0 { (amount_0, amount_1)} else { (amount_1, amount_0) };
            assert(amount_a >= amount_a_min, 'INSUFFICIENT A AMOUNT');
            assert(amount_b >= amount_b_min, 'INSUFFICIENT B AMOUNT');
            (amount_a, amount_b)
        }

        fn swap_exact_tokens_for_tokens(
            ref self: ContractState,
            amount_in: u256,
            amount_out_min: u256,
            path: Array<ContractAddress>,
            to: ContractAddress,
            deadline: u64,
        ) -> Array<u256> {
            let factory = self.factory.read();
            let pair_class_hash = self.pair_class_hash.read();
            let caller = get_caller_address();
            self.ensure_deadline(deadline);
            let amounts = Library::get_amounts_out(factory, amount_in, path.clone());

            assert(amounts.at(amounts.len() - 1) > @amount_out_min, 'INSUFFICIENT OUTPUT AMOUNT');
            let token_dispatcher = IERC20Dispatcher { contract_address: *path.at(0) };
            token_dispatcher.transfer_from(caller, Library::pair_for(factory, pair_class_hash, *path.at(0), *path.at(1)).unwrap(), *amounts.at(0));
            self._swap(amounts.span(), path.span(), to);
            amounts
        }

        fn swap_tokens_for_exact_tokens(
            ref self: ContractState,
            amount_out: u256,
            amount_in_max: u256,
            path: Array<ContractAddress>,
            to: ContractAddress,
            deadline: u64,
        ) -> Array<u256> {
            let (factory, pair_class_hash, caller) = (
                self.factory.read(), self.pair_class_hash.read(), get_caller_address()
            );
            let amounts = Library::get_amounts_in(factory, amount_out, path.clone());
            assert(amounts.at(0) < @amount_in_max, 'EXCESSIVE INPUT AMOUNT');
            
            let token_dispatcher = IERC20Dispatcher { contract_address: *path.at(0) };
            token_dispatcher.transfer_from(caller, Library::pair_for(factory, pair_class_hash, *path.at(0), *path.at(1)).unwrap(), *amounts.at(0));
            self._swap(amounts.span(), path.span(), to);
            amounts
        }


        fn quote(
            self: @ContractState, amount_a: u256, reserve_a: u256, reserve_b: u256,
        ) -> u256 {
            Library::quote(amount_a, reserve_a, reserve_b)
        } // amount_b
        fn get_amount_out(
            self: @ContractState, amount_in: u256, reserve_in: u256, reserve_out: u256,
        ) -> u256 {
            Library::get_amount_out(amount_in, reserve_in, reserve_out)
        } // amount_out
        fn get_amount_in(
            self: @ContractState, amount_out: u256, reserve_in: u256, reserve_out: u256,
        ) -> u256 {
            Library::get_amount_in(amount_out, reserve_in, reserve_out)
        } // amount_in
        fn get_amounts_out(
            self: @ContractState, amount_in: u256, path: Array<ContractAddress>,
        ) -> Array<u256> {
            let factory = self.factory.read();
            Library::get_amounts_out(factory, amount_in, path)
        } // amounts
        fn get_amounts_in(
            self: @ContractState, amount_out: u256, path: Array<ContractAddress>,
        ) -> Array<u256> {
            let factory = self.factory.read();
            // let pair_class_hash = self.pair_class_hash.read();
            Library::get_amounts_in(factory, amount_out, path)
        } // amounts
    }
}
