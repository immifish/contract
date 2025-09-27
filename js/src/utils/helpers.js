import { formatUnits, parseUnits } from 'ethers';

/**
 * Format token amount from wei to readable format
 * @param {string|BigNumber} amount - Amount in wei
 * @param {number} decimals - Token decimals
 * @returns {string} Formatted amount
 */
export function formatTokenAmount(amount, decimals = 18) {
  return formatUnits(amount, decimals);
}

/**
 * Parse token amount from readable format to wei
 * @param {string} amount - Amount in readable format
 * @param {number} decimals - Token decimals
 * @returns {BigNumber} Amount in wei
 */
export function parseTokenAmount(amount, decimals = 18) {
  return parseUnits(amount, decimals);
}

/**
 * Format percentage (e.g., 1000 -> "10%")
 * @param {number} value - Value in basis points
 * @param {number} scale - Scale factor (default 10000 for basis points)
 * @returns {string} Formatted percentage
 */
export function formatPercentage(value, scale = 10000) {
  return `${(value / scale * 100).toFixed(2)}%`;
}

/**
 * Sleep function for delays
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise} Promise that resolves after delay
 */
export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry function with exponential backoff
 * @param {Function} fn - Function to retry
 * @param {number} maxRetries - Maximum number of retries
 * @param {number} baseDelay - Base delay in milliseconds
 * @returns {Promise} Promise that resolves with function result
 */
export async function retry(fn, maxRetries = 3, baseDelay = 1000) {
  let lastError;
  
  for (let i = 0; i <= maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (i === maxRetries) break;
      
      const delay = baseDelay * Math.pow(2, i);
      await sleep(delay);
    }
  }
  
  throw lastError;
}
