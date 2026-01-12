pub mod Library {
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::pedersen::{pedersen};
    use core::poseidon::PoseidonTrait;
    use openzeppelin::token::erc20::interface::{
        IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::factory::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
    use crate::pair::ipair::{IPairDispatcher, IPairDispatcherTrait};

    pub fn get_salt(tokenA: ContractAddress, tokenB: ContractAddress) -> felt252 {
        assert(tokenA != tokenB, 'Identical Tokens');
        let (token0, token1) = sort_tokens(tokenA, tokenB);
        let salt = PoseidonTrait::new();
        let felt_salt: felt252 = salt.update_with(token0).update_with(token1).finalize();
        felt_salt
    }

    pub fn get_lp_token_metadata(
        tokenA: ContractAddress, tokenB: ContractAddress,
    ) -> (ByteArray, ByteArray) {
        let (token0, token1) = sort_tokens(tokenA, tokenB);
        let token0_dispatcher = IERC20MetadataDispatcher { contract_address: token0 };
        let token1_dispatcher = IERC20MetadataDispatcher { contract_address: token1 };

        let token0_name = token0_dispatcher.name();
        let token0_symbol = token0_dispatcher.symbol();
        let token1_name = token1_dispatcher.name();
        let token1_symbol = token1_dispatcher.symbol();

        let lp_token_name = token0_name + token1_name;
        let lp_token_symbol = token0_symbol + token1_symbol;

        (lp_token_name, lp_token_symbol)
    }

    pub fn compute_hash_on_elements(data: Span<felt252>) -> felt252 {
        let mut acc: felt252 = 0;
        let mut i = 0;

        while i < data.len() {
            acc = pedersen(acc, *data.at(i));
            i += 1;
        }

        // Append length
        acc = pedersen(acc, data.len().into());
        acc
    }

    pub fn sort_tokens(
        // self: @ComponentState<TContractState>,
        token_a: ContractAddress, token_b: ContractAddress,
    ) -> (ContractAddress, ContractAddress) { // token0, token1
        assert(token_a != token_b, 'IDENTICAL TOKENS');
        let (token0, token1) = if token_a < token_b {
            (token_a, token_b)
        } else {
            (token_b, token_a)
        };
        assert(token0 != Zero::zero(), 'ZERO ADDRESS');
        (token0, token1)
    }

    // calculates the address for a pair without making any external calls (thanks to deterministic
    // values)
    pub fn pair_for(
        // self: @ComponentState<TContractState>,
        factory: ContractAddress,
        pair_class_hash: ClassHash,
        token_a: ContractAddress,
        token_b: ContractAddress,
    ) -> Option<ContractAddress> { //pair contract address
        let (token0, token1) = sort_tokens(token_a, token_b);
        let (name, symbol) = get_lp_token_metadata(token0, token1);

        let mut constructor_calldata = ArrayTrait::new();
        token0.serialize(ref constructor_calldata);
        token1.serialize(ref constructor_calldata);
        name.serialize(ref constructor_calldata);
        symbol.serialize(ref constructor_calldata);

        let constructor_calldata_hash = compute_hash_on_elements(constructor_calldata.span());
        let deploy_salt = get_salt(token0, token1);
        let deployer_address: felt252 = factory.into();
        // let pair_class_hash = self.pair_class_hash.read().into();

        let mut addr_elements = ArrayTrait::new();
        'STARKNET_CONTRACT_ADDRESS'.serialize(ref addr_elements);
        deployer_address.serialize(ref addr_elements);
        deploy_salt.serialize(ref addr_elements);
        pair_class_hash.serialize(ref addr_elements);
        constructor_calldata_hash.serialize(ref addr_elements);
        // let state = PedersenTrait::new(0)
        //     .update('STARKNET_CONTRACT_ADDRESS')
        //     .update(deployer_address)
        //     .update(deploy_salt)
        //     .update(pair_class_hash.into())
        //     .update(constructor_calldata_hash)
        //     .finalize();
        let elements_hash = compute_hash_on_elements(addr_elements.span());
        elements_hash.try_into()
    }

    // fetches and sorts the reserves for a pair
    pub fn get_reserves(
        // self: @ComponentState<TContractState>,
        factory: ContractAddress, // pair_class_hash: ClassHash,
        token_a: ContractAddress, token_b: ContractAddress,
    ) -> (u256, u256) { // reserve_a, reserve_b
        let (token_0, token_1) = sort_tokens(token_a, token_b);
        // let pair_contract = pair_for(factory, pair_class_hash, token_0, token_1);
        let factory_dispatcher = IFactoryDispatcher { contract_address: factory };
        let pair_contract = factory_dispatcher.get_pair(token_0, token_1);

        // if let Some(contract) = pair_contract {
        //     let pair_dispatcher = IPairDispatcher { contract_address: contract };
        //     let (reserve0, reserve1, _) = pair_dispatcher.get_reserves_pub();
        //     (reserve0, reserve1)
        // } else {
        //     (0, 0)
        // }
        assert(!(pair_contract.is_zero()), 'ZERO ADDRESS PAIR: NOT DEPLOYED');

        let pair_dispatcher = IPairDispatcher { contract_address: pair_contract };
        let (reserve0, reserve1, _) = pair_dispatcher.get_reserves_pub();
        (reserve0, reserve1)
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other
    // asset
    pub fn quote(amount_a: u256, reserve_a: u256, reserve_b: u256) -> u256 { // amount_b
        assert(amount_a != 0, 'INSUFFICIENT AMOUNT');
        assert(reserve_a > 0 && reserve_b > 0, 'INSUFFICIENT LIQUIDITY');
        let amount_b = (amount_a * reserve_b) / reserve_a;
        amount_b
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the
    // other asset 3 percent fee implemented
    pub fn get_amount_out(
        // self: @ComponentState<TContractState>,
        amount_in: u256, reserve_in: u256, reserve_out: u256,
    ) -> u256 { // amount_out
        assert(amount_in > 0, 'INSUFFICIENT LIQUIDITY');
        assert(reserve_in > 0 && reserve_out > 0, 'INSUFFICIENT LIQUIDITY');
        let amount_in_with_fee = amount_in * 997;
        let numerator = amount_in_with_fee * reserve_out;
        let denominator = amount_in_with_fee + (1000 * reserve_in);

        let amount_out = numerator / denominator;
        amount_out
    }

    pub fn get_amount_in(
        // self: @ComponentState<TContractState>,
        amount_out: u256, reserve_in: u256, reserve_out: u256,
    ) -> u256 { // amount_in
        assert(amount_out > 0, 'INSUFFICIENT AMOUNT');
        assert(reserve_in > 0 && reserve_out > 0, 'INSUFFICIENT LIQUIDITY');
        let amount_out_with_fee = amount_out * 997;
        let numerator = amount_out_with_fee * reserve_in * 1000;
        let denominator = (1000 * reserve_out) - amount_out_with_fee;

        let amount_in = numerator / denominator;
        amount_in + 1
    }

    pub fn get_amounts_out(
        factory: ContractAddress, amount_in: u256, path: Array<ContractAddress>,
        // pair_class_hash: ClassHash,
    ) -> Array<u256> {
        assert(path.len() >= 2, 'INVALID PATH');
        let mut amounts = array![];

        amounts.append(amount_in);
        for i in 0..path.len() {
            let (reserve_in, reserve_out) = get_reserves(
                factory, // pair_class_hash,
                *path.get(i).unwrap().unbox(), *path.get(i).unwrap().unbox(),
            );
            amounts
                .append(get_amount_out(*amounts.get(i).unwrap().unbox(), reserve_in, reserve_out));
        }

        amounts
    }

    pub fn get_amounts_in(
        // self: @ComponentState<TContractState>,
        factory: ContractAddress, // pair_class_hash: ClassHash,
        amount_out: u256, path: Array<ContractAddress>,
    ) -> Array<u256> {
        let path_length = path.len();
        assert(path.len() >= 2, 'INVALID PATH');
        let mut amounts: Array<u256> = array![];

        amounts.append(amount_out);

        // for i in 0..path.len() {
        //     let (reserve_in, reserve_out) = self.get_reserves(factory, *path.at(path_length - i -
        //     2), *path.at(path_length - i - 1));
        //     amounts.append(self.get_amount_in(*amounts.get(i - 1).unwrap().unbox(), reserve_in,
        //     reserve_out))
        // }

        let mut i = 0;

        while i < (path_length - 1) {
            let idx_in = path_length - i - 2;
            let idx_out = path_length - i - 1;

            let (reserve_in, reserve_out) = get_reserves(
                factory, // pair_class_hash,
                *path.get(idx_in).unwrap().unbox(), *path.get(idx_out).unwrap().unbox(),
            );
            let amount_current = *amounts.at(i);
            let amount_prev = get_amount_in(amount_current, reserve_in, reserve_out);

            amounts.append(amount_prev);
            i += 1
        }

        let mut new_arr: Array<u256> = array![];
        let amounts_length = amounts.len();

        let mut j = 0;
        // for i in 0..amounts_length {
        //     let reverse_value = *amounts.at(amounts_length - i - 1);
        //     new_arr.append(reverse_value);
        // }

        while j < amounts_length {
            let reverse_value = *amounts.at(amounts_length - j - 1);
            new_arr.append(reverse_value);
            j += 1
        }

        new_arr
    }
}
