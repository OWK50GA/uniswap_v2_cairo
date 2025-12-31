#[starknet::contract]
pub mod factory {
    // use starknet::contract_address::ContractAddressZeroable;
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::poseidon::PoseidonTrait;
    use openzeppelin::token::erc20::interface::{
        IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait,
    };
    use starknet::class_hash::ClassHash;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ContractAddress, SyscallResultTrait, get_block_timestamp, get_caller_address,
        // get_contract_address,
    };
    use uniswap_v2::factory::ifactory::IFactory;
    use crate::library::library::Library;

    #[storage]
    pub struct Storage {
        fee_to: ContractAddress, // address that receives the fee
        owner: ContractAddress, // address that has the authority to set the fee
        pair: Map<
            (ContractAddress, ContractAddress), ContractAddress,
        >, // Maps the address of a pair contract to the tokens the pair holds, in any order
        all_pairs: Vec<ContractAddress>, // Vec of all pairs that exist
        pair_class_hash: ClassHash, // stores the class hash of the pair contract
        lp_token_class_hash: ClassHash // class hash of the liquidity pool token
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PairCreated: PairCreated,
        OwnershipTransferred: OwnershipTransferred,
        FeeToSet: FeeToSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PairCreated {
        #[key]
        token_symbol: ByteArray,
        #[key]
        token0: ContractAddress,
        #[key]
        token1: ContractAddress,
        pair: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnershipTransferred {
        #[key]
        prev_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeToSet {
        fee_to: ContractAddress,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    // fn sort_tokens(
    //     tokenA: ContractAddress, tokenB: ContractAddress,
    // ) -> (ContractAddress, ContractAddress) {
    //     if (tokenA < tokenB) {
    //         (tokenA, tokenB)
    //     } else {
    //         (tokenB, tokenA)
    //     }
    // }

    fn get_salt(tokenA: ContractAddress, tokenB: ContractAddress) -> felt252 {
        let salt = PoseidonTrait::new();
        let felt_salt: felt252 = salt.update_with(tokenA).update_with(tokenB).finalize();
        felt_salt
    }

    fn get_lp_token_metadata(
        tokenA: ContractAddress, tokenB: ContractAddress,
    ) -> (ByteArray, ByteArray) {
        let tokenA_dispatcher = IERC20MetadataDispatcher { contract_address: tokenA };
        let tokenB_dispatcher = IERC20MetadataDispatcher { contract_address: tokenB };

        let tokenA_name = tokenA_dispatcher.name();
        let tokenA_symbol = tokenA_dispatcher.symbol();
        let tokenB_name = tokenB_dispatcher.name();
        let tokenB_symbol = tokenB_dispatcher.symbol();

        let lp_token_name = tokenA_name + tokenB_name;
        let lp_token_symbol = tokenA_symbol + tokenB_symbol;

        (lp_token_name, lp_token_symbol)
    }

    #[abi(embed_v0)]
    pub impl FactoryImpl of IFactory<ContractState> {
        fn all_pairs_length(self: @ContractState) -> u64 {
            self.all_pairs.len()
        }

        fn create_pair(
            ref self: ContractState, tokenA: ContractAddress, tokenB: ContractAddress,
        ) -> ContractAddress {
            assert(tokenA != tokenB, 'Identical Address Pair Attempt');
            let (token0, token1) = Library::sort_tokens(tokenA, tokenB);
            assert(!token0.is_zero(), 'Zero Address Pair Attempt');
            assert(self.pair.entry((token0, token1)).read().is_zero(), 'Pair already exists');

            let (token_name, token_symbol) = get_lp_token_metadata(token0, token1);

            // Deploy the LP TOken for this pair
            // let lp_token = self.deploy_lp_token(token0, token1);

            // Deploy the pair contract
            let mut constructor_calldata: Array<felt252> = array![];
            // serialize the constructor params like so:
            // let param = x
            // param.serialize(ref constructor_calldata);
            token0.serialize(ref constructor_calldata);
            token1.serialize(ref constructor_calldata);
            token_name.serialize(ref constructor_calldata);
            token_symbol.serialize(ref constructor_calldata);
            // lp_token.serialize(ref constructor_calldata);

            let felt_salt = get_salt(token0, token1);
            let pair_class_hash = self.pair_class_hash.read();
            let result = deploy_syscall(
                pair_class_hash, felt_salt, constructor_calldata.span(), false,
            );
            let (pair_address, _) = result.unwrap_syscall();
            self.pair.entry((token0, token1)).write(pair_address);
            // self.pair.entry((token1, token0)).write(pair_address);
            self.all_pairs.push(pair_address);
            self
                .emit(
                    PairCreated {
                        token_symbol,
                        token0,
                        token1,
                        pair: pair_address,
                        timestamp: get_block_timestamp(),
                    },
                );

            pair_address
        }

        fn get_pair(
            self: @ContractState, tokenA: ContractAddress, tokenB: ContractAddress,
        ) -> ContractAddress {
            // let pair_contract = Library::pair_for(
            //     get_contract_address(), self.pair_class_hash.read(), tokenA, tokenB,
            // );
            // assert(pair_contract.is_some(), 'NO SUCH PAIR CONTRACT');
            // pair_contract.unwrap()
            let (token_0, token_1) = Library::sort_tokens(tokenA, tokenB);
            let pair_contract = self.pair.entry((token_0, token_1)).read();
            pair_contract
        }

        fn set_fee_to(ref self: ContractState, fee_to: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can set fee');
            self.fee_to.write(fee_to);
            self.emit(FeeToSet { fee_to, timestamp: get_block_timestamp() });
        }

        fn set_new_owner(ref self: ContractState, new_owner: ContractAddress) {
            let caller = get_caller_address();
            let prev_owner = self.owner.read();
            assert!(caller == prev_owner, "only owner can transfer ownership");
            self.owner.write(new_owner);
            self
                .emit(
                    OwnershipTransferred {
                        prev_owner, new_owner, timestamp: get_block_timestamp(),
                    },
                );
        }

        fn get_fee_to(self: @ContractState) -> ContractAddress {
            let fee_to = self.fee_to.read();
            if fee_to.is_zero() {
                Zero::zero()
            } else {
                fee_to
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalFunctions {
        fn deploy_lp_token(
            self: @ContractState, token0: ContractAddress, token1: ContractAddress,
        ) -> ContractAddress {
            let (token_name, token_symbol) = get_lp_token_metadata(token0, token1);

            let mut constructor_calldata = array![];
            token_name.serialize(ref constructor_calldata);
            token_symbol.serialize(ref constructor_calldata);

            // Same salt is used to deploy the lp token and the pair contract
            let felt_salt = get_salt(token0, token1);

            let lp_token_class_hash = self.lp_token_class_hash.read();

            let result = deploy_syscall(
                lp_token_class_hash, felt_salt, constructor_calldata.span(), false,
            );

            let (address, _) = result.unwrap_syscall();

            address
        }
    }
}
