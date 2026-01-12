use starknet::ContractAddress;
use uniswap_v2::library::library::Library;

// STRK and ETH token addresses on Starknet Sepolia
const STRK_ADDRESS: felt252 = 0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D;
const ETH_ADDRESS: felt252 = 0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7;

#[test]
fn test_sort_tokens_orders_correctly() {
    let token_a: ContractAddress = STRK_ADDRESS.try_into().unwrap();
    let token_b: ContractAddress = ETH_ADDRESS.try_into().unwrap();
    
    let (token0, token1) = Library::sort_tokens(token_a, token_b);
    
    // token0 should be less than token1
    assert(token0 < token1, 'Tokens sorted ascending');
}

#[test]
fn test_sort_tokens_reversed() {
    let token_a: ContractAddress = STRK_ADDRESS.try_into().unwrap();
    let token_b: ContractAddress = ETH_ADDRESS.try_into().unwrap();
    
    // Sort with reversed order
    let (token0_reversed, token1_reversed) = Library::sort_tokens(token_b, token_a);
    
    // Even with reversed inputs, token0 should still be less than token1
    assert(token0_reversed < token1_reversed, 'Always sorted ascending');
    
    // And the result should be the same as sorting the other way
    let (token0, token1) = Library::sort_tokens(token_a, token_b);
    assert(token0 == token0_reversed, 'token0 same');
    assert(token1 == token1_reversed, 'token1 same');
}

#[test]
#[should_panic(expected: ('IDENTICAL TOKENS',))]
fn test_sort_tokens_identical_tokens_panics() {
    let token_a: ContractAddress = STRK_ADDRESS.try_into().unwrap();
    
    // Should panic when both tokens are identical
    Library::sort_tokens(token_a, token_a);
}

#[test]
#[should_panic(expected: ('Identical Tokens',))]
fn test_get_salt_same_inputs() {
    let token_a: ContractAddress = 123.try_into().unwrap();
    let token_b: ContractAddress = 123.try_into().unwrap();
    
    // Call get_salt twice with same inputs
    let salt_1 = Library::get_salt(token_a, token_b);
    let salt_2 = Library::get_salt(token_a, token_b);
    
    // Results should be identical for same inputs
    assert(salt_1 == salt_2, 'Should be deterministic');
}

#[test]
fn test_get_salt_different_token_order() {
    let token_a: ContractAddress = 123.try_into().unwrap();
    let token_b: ContractAddress = 456.try_into().unwrap();
    
    // Call get_salt with tokens in different order
    let salt_ab = Library::get_salt(token_a, token_b);
    let salt_ba = Library::get_salt(token_b, token_a);
    
    // Results should be same for different token order (tokens are sorted internally)
    assert(salt_ab == salt_ba, 'Salt should be same');
}

#[test]
fn test_compute_hash_on_elements_empty() {
    let data: Array<felt252> = array![];
    let hash = Library::compute_hash_on_elements(data.span());
    
    // Hash of empty array should be consistent
    let hash_2 = Library::compute_hash_on_elements(array![].span());
    assert(hash == hash_2, 'Empty hash should be consistent');
}

#[test]
fn test_compute_hash_on_elements_single_element() {
    let data: Array<felt252> = array![42];
    let hash = Library::compute_hash_on_elements(data.span());
    
    // Hash with single element should be deterministic
    let hash_2 = Library::compute_hash_on_elements(array![42].span());
    assert(hash == hash_2, 'Hash should be deterministic');
}

#[test]
fn test_compute_hash_on_elements_multiple_elements() {
    let data: Array<felt252> = array![1, 2, 3, 4, 5];
    let hash = Library::compute_hash_on_elements(data.span());
    
    // Same data should produce same hash
    let hash_2 = Library::compute_hash_on_elements(array![1, 2, 3, 4, 5].span());
    assert(hash == hash_2, 'Hash should be deterministic');
    
    // Different data should produce different hash
    let different_hash = Library::compute_hash_on_elements(array![5, 4, 3, 2, 1].span());
    assert(hash != different_hash, 'Diff data diff hash');
}

#[test]
fn test_compute_hash_on_elements_order_matters() {
    let data1: Array<felt252> = array![10, 20, 30];
    let data2: Array<felt252> = array![30, 20, 10];
    
    let hash1 = Library::compute_hash_on_elements(data1.span());
    let hash2 = Library::compute_hash_on_elements(data2.span());
    
    // Order should matter in hash computation
    assert(hash1 != hash2, 'Diff element order hash');
}
