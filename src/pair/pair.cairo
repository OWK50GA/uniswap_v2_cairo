#[starknet::contract]
pub mod Pair {
    use ERC20Component::{ERC20MixinImpl, InternalImpl};
    use core::num::traits::{Sqrt, Zero};
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    // use uniswap_v2::lp_token::ilp_token::{ILPTokenDispatcher, ILPTokenDispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use uniswap_v2::factory::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
    use uniswap_v2::pair::ipair::IPair;

    #[storage]
    pub struct Storage {
        minimum_liquidity: u256,
        factory: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
        // lp_token: ContractAddress,
        k_last: u256,
        reserve0: u256, // amount of token0 the contract has
        reserve1: u256, // amount of token1 the contract has
        initialized: bool, // this tracks whether the first liquidity provider has provided liquidity
        // owner: ContractAddress, // owner should be the factory
        block_timestamp_last: u64,
        price0_cumulative_last: u256,
        price1_cumulative_last: u256,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    // * TODO: IMPLEMENT A REENTRANCY GUARD TO REPLACE THE LOCK MODIFIER * /

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Mint: Mint,
        Burn: Burn,
        Swap: Swap,
        Sync: Sync,
        ERC20Event: ERC20Component::Event,
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Mint {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Burn {
        #[key]
        sender: ContractAddress,
        amount0: u256,
        amount1: u256,
        #[key]
        to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Swap {
        #[key]
        sender: ContractAddress,
        amount0_in: u256,
        amount1_in: u256,
        amount0_out: u256,
        amount1_out: u256,
        to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Sync {
        reserve0: u256,
        reserve1: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token0: ContractAddress,
        token1: ContractAddress,
        // lp_token: ContractAddress,
        lp_token_name: ByteArray,
        lp_token_symbol: ByteArray,
    ) {
        let minimum_liquidity = 10 * 10 * 10;
        self.minimum_liquidity.write(minimum_liquidity);
        self.token0.write(token0);
        self.token1.write(token1);
        self.initialized.write(false);
        self.reserve0.write(0);
        self.reserve1.write(0);
        self.factory.write(get_caller_address());
        self.erc20.initializer(lp_token_name, lp_token_symbol);
    }

    #[abi(embed_v0)]
    impl ER20Impl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl PairImpl of IPair<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress) -> u256 {
            self.reentrancy_guard.start();
            let (reserve0, reserve1, _) = self.get_reserves();

            let contract_address = get_contract_address();
            let token0_dispatcher = IERC20Dispatcher { contract_address: self.token0.read() };
            let token1_dispatcher = IERC20Dispatcher { contract_address: self.token1.read() };

            let balance0 = token0_dispatcher
                .balance_of(contract_address); // contract balance of token0
            let balance1 = token1_dispatcher
                .balance_of(contract_address); // contract balance of token1

            // subtracting what was in reserve from balance to see the amount the user sent
            let (amt0, amt1) = (balance0 - reserve0, balance1 - reserve1);

            let fee_on = self._mint_fee(reserve0, reserve1);

            let total_shares = self.erc20.total_supply();
            let mut liquidity: u256 = 0;

            if (total_shares == 0) {
                // This means this is the first liquidity
                liquidity = (amt0 * amt1).sqrt().into() - self.minimum_liquidity.read();
                self
                    .erc20
                    .mint(
                        Zero::zero(), self.minimum_liquidity.read(),
                    ); //permanently lock the first minimum liquidity, so pool can never be drained
            } else {
                let (ratio0, ratio1) = (amt0 / reserve0, amt1 / reserve1);
                if (ratio0 < ratio1) {
                    liquidity = amt0 * total_shares / reserve0;
                } else {
                    liquidity = amt1 * total_shares / reserve1;
                }
            }

            assert(liquidity > 0, 'INSUFFICIENT LIQUIDITY MINTED');
            self.erc20.mint(to, liquidity);

            self._update(balance0, balance1, reserve0, reserve1);
            if fee_on {
                self.k_last.write(reserve0 * reserve1);
            }
            self.emit(Mint { sender: get_caller_address(), amount0: amt0, amount1: amt1 });
            self.reentrancy_guard.end();
            liquidity
        }

        fn burn(ref self: ContractState, to: ContractAddress) -> (u256, u256) {
            self.reentrancy_guard.start();
            let (reserve0, reserve1, _) = self.get_reserves();

            let contract_address = get_contract_address();

            let token0_dispatcher = IERC20Dispatcher { contract_address: self.token0.read() };
            let token1_dispatcher = IERC20Dispatcher { contract_address: self.token1.read() };
            // let lptoken_dispatcher = IERC20Dispatcher { contract_address: self.lp_token.read() };

            let balance0 = token0_dispatcher.balance_of(contract_address);
            let balance1 = token1_dispatcher.balance_of(contract_address);

            let liquidity = self.erc20.balance_of(contract_address);

            let fee_on = self._mint_fee(reserve0, reserve1);

            let total_supply = self.erc20.total_supply();

            let amt0 = liquidity * balance0 / total_supply;
            let amt1 = liquidity * balance1 / total_supply;

            assert(amt0 > 0 && amt1 > 0, 'Insufficient Liquidity Burned');
            self.erc20.burn(contract_address, liquidity);

            token0_dispatcher.transfer(to, amt0);
            token1_dispatcher.transfer(to, amt1);

            let balance0 = token0_dispatcher.balance_of(contract_address);
            let balance1 = token1_dispatcher.balance_of(contract_address);

            self._update(balance0, balance1, reserve0, reserve1);

            if fee_on {
                let k_last = balance0 * balance1;
                self.k_last.write(k_last);
            }
            self.emit(Burn { sender: get_caller_address(), amount0: amt0, amount1: amt1, to });
            self.reentrancy_guard.end();
            (amt0, amt1)
        }

        fn swap(
            ref self: ContractState, amount0_out: u256, amount1_out: u256, to: ContractAddress,
        ) {
            // TODO: IMPORTANT FLASH SWAP HERE LATER
            self.reentrancy_guard.start();
            assert(amount0_out > 0 || amount1_out > 0, 'INSUFFICIENT OUTPUT AMOUNT');
            assert(!(amount0_out > 0 && amount1_out > 0), 'Both cannot exceed zero');

            let (reserve0, reserve1, _) = self.get_reserves();
            let contract_address = get_contract_address();

            assert(amount0_out < reserve0 && amount1_out < reserve1, 'Insufficient Liquidity');

            let token0_dispatcher = IERC20Dispatcher { contract_address: self.token0.read() };
            let token1_dispatcher = IERC20Dispatcher { contract_address: self.token1.read() };

            assert(to != self.token0.read() && to != self.token1.read(), 'INVALID TO');

            if (amount0_out > 0) {
                token0_dispatcher.transfer(to, amount0_out);
            }
            if amount1_out > 0 {
                token1_dispatcher.transfer(to, amount1_out);
            }

            let balance0 = token0_dispatcher.balance_of(contract_address);
            let balance1 = token1_dispatcher.balance_of(contract_address);

            // let mut amount0_in = 0;
            // let mut amount1_in = 0;

            let amount0_in = if balance0 > (reserve0 - amount0_out) {
                balance0 - (reserve0 - amount0_out)
            } else {
                0
            };
            // if (balance0 > (reserve0 - amount0_out)) {
            //     amount0_in = balance0 - (reserve0 - amount0_out);
            // }
            let amount1_in = if balance1 > (reserve1 - amount1_out) {
                balance1 - (reserve1 - amount1_out)
            } else {
                0
            };
            // if (balance1 > (reserve1 - amount1_out)) {
            //     amount1_in = balance1 - (reserve1 - amount1_out);
            // }

            assert(amount0_in > 0 || amount1_in > 0, 'INSUFFICIENT INPUT AMOUNT');
            // assert(!(amount0_in > 0 && amount1_in > 0), 'Cannot send in both tokens');

            let adjusted_balance_0 = (balance0 * 1000) - (amount0_in * 3);
            let adjusted_balance_1 = (balance1 * 1000) - (amount1_in * 3);

            assert(
                (adjusted_balance_0 * adjusted_balance_1) >= (reserve0 * reserve1 * 1000 * 1000),
                'K error',
            );

            // let new_k = adjusted_balance_0 * adjusted_balance_1 / (1000 * 1000);
            // self.k_last.write(new_k);

            self._update(balance0, balance1, reserve0, reserve1);
            self
                .emit(
                    Swap {
                        sender: get_caller_address(),
                        amount0_in,
                        amount1_in,
                        amount0_out,
                        amount1_out,
                        to,
                    },
                );
            self.reentrancy_guard.end();
        }

        fn get_reserves_pub(self: @ContractState) -> (u256, u256, u64) {
            self.get_reserves()
        }

        fn skim(ref self: ContractState, to: ContractAddress) {
            self.reentrancy_guard.start();
            let token0_dispatcher = IERC20Dispatcher { contract_address: self.token0.read() };
            let token1_dispatcher = IERC20Dispatcher { contract_address: self.token1.read() };

            let (reserve0, reserve1, _) = self.get_reserves();
            let contract_address = get_contract_address();

            let balance0 = token0_dispatcher.balance_of(contract_address);
            let balance1 = token1_dispatcher.balance_of(contract_address);

            if balance0 > reserve0 {
                token0_dispatcher.transfer(to, balance0 - reserve0);
            }
            if balance1 > reserve1 {
                token1_dispatcher.transfer(to, balance1 - reserve1);
            }
            self.reentrancy_guard.end();
        }

        fn sync(ref self: ContractState) {
            self.reentrancy_guard.start();
            let token0_dispatcher = IERC20Dispatcher { contract_address: self.token0.read() };
            let token1_dispatcher = IERC20Dispatcher { contract_address: self.token1.read() };

            let contract_address = get_contract_address();
            let (reserve0, reserve1, _) = self.get_reserves();

            let balance0 = token0_dispatcher.balance_of(contract_address);
            let balance1 = token1_dispatcher.balance_of(contract_address);

            self._update(balance0, balance1, reserve0, reserve1);
            self.reentrancy_guard.end();
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalTrait {
        fn get_reserves(self: @ContractState) -> (u256, u256, u64) {
            let reserve0 = self.reserve0.read();
            let reserve1 = self.reserve1.read();
            let block_timestamp_last = self.block_timestamp_last.read();
            (reserve0, reserve1, block_timestamp_last)
        }

        fn safe_transfer(
            self: @ContractState, to: ContractAddress, value: u256, token: ContractAddress,
        ) { // This is for swapping, not for LP-ing
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(to, value);
        }

        fn _mint_fee(ref self: ContractState, reserve0: u256, reserve1: u256) -> bool {
            let factory_dispatcher = IFactoryDispatcher { contract_address: self.factory.read() };

            let fee_to = factory_dispatcher.get_fee_to();
            let total_shares = self.erc20.total_supply(); // Total number of shares
            let fee_on = !fee_to.is_zero();
            let mut k_last = self.k_last.read(); // current liquidity
            // if (fee_on && k_last != 0) {
            //     let root_k: u256 = (reserve0 * reserve1).sqrt().into();
            //     let root_k_last: u256 = k_last.sqrt().into();

            //     if root_k > root_k_last {
            //         let numerator = total_shares * (root_k - root_k_last);
            //         let denominator = (5 * root_k) + root_k_last;
            //         let liquidity = numerator / denominator;
            //         if (liquidity > 0) {
            //             self.erc20.mint(fee_to, liquidity);
            //         }
            //     }
            // } else if (!fee_on && k_last != 0) {
            //     k_last = 0;
            //     self.k_last.write(0);
            // }
            if fee_on {
                if k_last != 0 {
                    let root_k = (reserve0 * reserve1).sqrt().into();
                    let root_k_last = k_last.sqrt().into();

                    if root_k > root_k_last {
                        let numerator = total_shares * (root_k - root_k_last);
                        let denominator = (5 * root_k) + root_k_last;
                        let liquidity = numerator / denominator;
                        if liquidity > 0 {
                            self.erc20.mint(fee_to, liquidity)
                        };
                    }
                }
            } else if k_last != 0 {
                self.k_last.write(0);
            }

            fee_on
        }

        fn _update(
            ref self: ContractState, balance0: u256, balance1: u256, reserve0: u256, reserve1: u256,
        ) {
            // assert(balance0 <= -1, '') I don't think Cairo needs this
            let block_timestamp = get_block_timestamp();
            let time_elapsed = block_timestamp - self.block_timestamp_last.read();

            if (time_elapsed > 0 && reserve0 != 0 && reserve1 != 0) { // Price Oracle Calculation
                let price0_cumulative_last = reserve1 * time_elapsed.into() / reserve0;
                let price1_cumulative_last = reserve0 * time_elapsed.into() / reserve1;
                self.price0_cumulative_last.write(price0_cumulative_last);
                self.price1_cumulative_last.write(price1_cumulative_last);
            }

            self.reserve0.write(balance0);
            self.reserve1.write(balance1);
            self.block_timestamp_last.write(block_timestamp);
            self.emit(Sync { reserve0: balance0, reserve1: balance1 });
        }
    }
}
