use openzeppelin::token::erc20::interface::IERC20MetadataDispatcher;
// use openzeppelin::openzeppelin_token::erc20::interface::IERC20MetadataDispatcher;
use starknet::SyscallResultTrait;
use snforge_std::DeclareResultTrait;
use snforge_std::{
    ContractClassTrait, declare, start_cheat_caller_address, stop_cheat_caller_address,
};
use snforge_std::cheatcodes::contract_class::ContractClass;
use starknet::{ContractAddress};
use uniswap_v2::factory::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
use uniswap_v2::library::library::Library;

// STRK and ETH token addresses on Starknet Sepolia
const STRK_ADDRESS: felt252 = 0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D;
const ETH_ADDRESS: felt252 = 0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7;

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn declare_factory() -> ContractClass {
    let contract = declare("Factory").unwrap_syscall();
    *contract.contract_class()
}

fn declare_pair() -> ContractClass {
    let contract = declare("Pair").unwrap_syscall();
    *contract.contract_class()
}

fn deploy_token0() -> (ContractAddress, IERC20MetadataDispatcher) {
    let token0_contract = declare("ERC20").unwrap_syscall().contract_class();

    let mut constructor_calldata = ArrayTrait::new();

    let name: ByteArray = "ELECTRONICS";
    let symbol: ByteArray = "ECE";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let (token0_address, _) = token0_contract.deploy(@constructor_calldata).unwrap_syscall();

    (token0_address, IERC20MetadataDispatcher { contract_address: token0_address })
}

fn deploy_token1() -> (ContractAddress, IERC20MetadataDispatcher) {
    let token0_contract = declare("ERC20").unwrap_syscall().contract_class();

    let mut constructor_calldata = ArrayTrait::new();

    let name: ByteArray = "MECHATRONICS";
    let symbol: ByteArray = "MCE";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let (token0_address, _) = token0_contract.deploy(@constructor_calldata).unwrap_syscall();

    (token0_address, IERC20MetadataDispatcher { contract_address: token0_address })
}

fn deploy_token2() -> (ContractAddress, IERC20MetadataDispatcher) {
    let token0_contract = declare("ERC20").unwrap_syscall().contract_class();

    let mut constructor_calldata = ArrayTrait::new();

    let name: ByteArray = "TELECOMMUNICATIONS";
    let symbol: ByteArray = "TCE";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let (token0_address, _) = token0_contract.deploy(@constructor_calldata).unwrap_syscall();

    (token0_address, IERC20MetadataDispatcher { contract_address: token0_address })
}

fn get_tokens() -> (ContractAddress, ContractAddress) {
    let (token0, _) = deploy_token0();
    let (token1, _) = deploy_token1();

    (token0, token1)
}

fn deploy_factory() -> IFactoryDispatcher {
    let factory_class = declare_factory();
    let owner = owner();

    let pair_class = declare_pair();
    let pair_class_hash = pair_class.class_hash;

    let mut constructor_calldata = ArrayTrait::new();
    owner.serialize(ref constructor_calldata);
    owner.serialize(ref constructor_calldata); // fee_to
    pair_class_hash.serialize(ref constructor_calldata);
    // pair_class_hash.serialize(ref constructor_calldata); // lp_token_class_hash (same as pair since pair is ERC20)

    let (factory_address, _) = factory_class.deploy(@constructor_calldata).unwrap_syscall();

    IFactoryDispatcher { contract_address: factory_address }
}

#[test]
fn test_create_pair_successful() {
    let factory = deploy_factory();
    let (token0, token1) = get_tokens();

    // Create pair
    let pair_address = factory.create_pair(token0, token1);
    assert(pair_address != 0.try_into().unwrap(), 'Pair not created');

    // Verify get_pair returns same address
    // let (token0, token1) = Library::sort_tokens(token_a, token_b);
    let retrieved_pair = factory.get_pair(token0, token1);
    assert(pair_address == retrieved_pair, 'get_pair mismatch');

    // Verify pair in all_pairs
    let all_pairs_len = factory.all_pairs_length();
    assert(all_pairs_len == 1, 'all_pairs not updated');
}

#[test]
fn test_create_pair_get_pair_both_orders() {
    let factory = deploy_factory();
    // let token_a: ContractAddress = 123.try_into().unwrap();
    // let token_b: ContractAddress = 456.try_into().unwrap();
    let (token_a, token_b) = get_tokens();

    let pair_address = factory.create_pair(token_a, token_b);

    // get_pair with tokens in original order
    let pair_from_ab = factory.get_pair(token_a, token_b);
    
    // get_pair with tokens in reverse order
    let pair_from_ba = factory.get_pair(token_b, token_a);

    // Both should return same pair address
    assert(pair_address == pair_from_ab, 'pair_ab mismatch');
    assert(pair_address == pair_from_ba, 'pair_ba mismatch');
}

#[test]
fn test_create_multiple_pairs() {
    let factory = deploy_factory();
    // let token_a: ContractAddress = 123.try_into().unwrap();
    // let token_b: ContractAddress = 456.try_into().unwrap();
    let (token_a, token_b) = get_tokens();

    // Create two different pairs using same token as base
    factory.create_pair(token_a, token_b);
    
    // all_pairs length should be 1
    assert(factory.all_pairs_length() == 1, 'first pair not added');

    // Create another pair (simulated with different tokens)
    let (token_c, _) = deploy_token2();
    factory.create_pair(token_a, token_c);

    assert(factory.all_pairs_length() == 2, 'Second pair not added');
}

#[test]
#[should_panic(expected: ('Pair already exists',))]
fn test_create_pair_duplicate_fails() {
    let factory = deploy_factory();
    // let token_a: ContractAddress = 123.try_into().unwrap();
    // let token_b: ContractAddress = 456.try_into().unwrap();
    let (token_a, token_b) = get_tokens();

    // Create pair once
    factory.create_pair(token_a, token_b);
    
    // Try to create same pair again - should panic
    factory.create_pair(token_a, token_b);
    factory.create_pair(token_b, token_a);
}

#[test]
#[should_panic(expected: ('Identical Address Pair Attempt',))]
fn test_create_pair_identical_tokens() {
    let factory = deploy_factory();
    let (token_a, _) = deploy_token0();

    // Try to create pair with same token - should panic
    factory.create_pair(token_a, token_a);
}

#[test]
fn test_create_pair_vs_pair_for() {
    let factory = deploy_factory();
    // let token_a: ContractAddress = 123.try_into().unwrap();
    // let token_b: ContractAddress = 456.try_into().unwrap();
    let (token_a, token_b) = get_tokens();
    
    // Get pair class hash
    let pair_class = declare_pair();
    let pair_class_hash = pair_class.class_hash;
    
    // Create pair through factory
    let pair_from_factory = factory.create_pair(token_a, token_b);
    
    // Calculate pair address using Library::pair_for
    let pair_from_library = Library::pair_for(
        factory.contract_address, pair_class_hash, token_a, token_b
    );
    
    // Both should return the same address
    assert(pair_from_library.is_some(), 'pair_for returned None');
    let pair_from_library_addr = pair_from_library.unwrap();
    assert(pair_from_factory == pair_from_library_addr, 'factory pair mismatch');
}

#[test]
fn test_set_fee_to_by_owner() {
    let factory = deploy_factory();
    let owner_addr = owner();
    let new_fee_to: ContractAddress = 'new_fee_to'.try_into().unwrap();

    // Start cheat as owner
    start_cheat_caller_address(factory.contract_address, owner_addr);
    
    factory.set_fee_to(new_fee_to);
    
    // Verify fee_to was updated
    let fee_to = factory.get_fee_to();
    assert(fee_to == new_fee_to, 'fee_to not updated');
    
    stop_cheat_caller_address(factory.contract_address);
}

#[test]
#[should_panic(expected: ('Only owner can set fee',))]
fn test_set_fee_to_non_owner_fails() {
    let factory = deploy_factory();
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();
    let new_fee_to: ContractAddress = 'new_fee_to'.try_into().unwrap();

    // Start cheat as non-owner
    start_cheat_caller_address(factory.contract_address, non_owner);
    
    // Should panic when non-owner tries to set fee
    factory.set_fee_to(new_fee_to);
}

#[test]
fn test_set_new_owner_by_owner() {
    let factory = deploy_factory();
    let owner_addr = owner();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();

    // Start cheat as owner
    start_cheat_caller_address(factory.contract_address, owner_addr);
    
    factory.set_new_owner(new_owner);
    
    // Verify ownership was transferred
    stop_cheat_caller_address(factory.contract_address);
    
    // Now try to set fee as new owner (only new owner should be able to)
    start_cheat_caller_address(factory.contract_address, new_owner);
    let new_fee_to: ContractAddress = 'fee'.try_into().unwrap();
    factory.set_fee_to(new_fee_to);
    
    let fee_to = factory.get_fee_to();
    assert(fee_to == new_fee_to, 'new owner no access');
    
    stop_cheat_caller_address(factory.contract_address);
}

#[test]
#[should_panic(expected: ('Caller not owner',))]
fn test_set_new_owner_non_owner_fails() {
    let factory = deploy_factory();
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();
    let new_owner: ContractAddress = 'another'.try_into().unwrap();

    // Start cheat as non-owner
    start_cheat_caller_address(factory.contract_address, non_owner);
    
    // Should panic when non-owner tries to transfer ownership
    factory.set_new_owner(new_owner);
}

#[test]
fn test_set_fee_to_zero_address() {
    let factory = deploy_factory();
    let owner_addr = owner();
    let zero_addr: ContractAddress = 0.try_into().unwrap();

    // Start cheat as owner
    start_cheat_caller_address(factory.contract_address, owner_addr);
    
    factory.set_fee_to(zero_addr);
    
    // Verify fee_to was set to zero
    let fee_to = factory.get_fee_to();
    assert(fee_to == zero_addr, 'fee_to not zero');
    
    stop_cheat_caller_address(factory.contract_address);
}

#[test]
fn test_set_fee_to_multiple_times() {
    let factory = deploy_factory();
    let owner_addr = owner();
    let fee_to_1: ContractAddress = 'fee1'.try_into().unwrap();
    let fee_to_2: ContractAddress = 'fee2'.try_into().unwrap();

    start_cheat_caller_address(factory.contract_address, owner_addr);
    
    // Set fee_to first time
    factory.set_fee_to(fee_to_1);
    let current_fee = factory.get_fee_to();
    assert(current_fee == fee_to_1, 'first fee not set');
    
    // Set fee_to second time
    factory.set_fee_to(fee_to_2);
    let updated_fee = factory.get_fee_to();
    assert(updated_fee == fee_to_2, 'second fee not set');
    
    stop_cheat_caller_address(factory.contract_address);
}
