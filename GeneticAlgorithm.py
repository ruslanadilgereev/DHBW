# Given data
import numpy as np


R = np.zeros((3,8))
P = np.array([[1, 2, 1, 2, 3, 1],
               [2, 1, 3, 1, 2, 2],
               [2, 3, 2, 1, 1, 3],
               [1, 1, 2, 2, 3, 2]])

endzeit_B1 = np.zeros(8)
endzeit_B2 = np.zeros(8)
endzeit_B3 = np.zeros(8)

##for n in range(8):
##    # For Band 1
##    if n == 0:
##        endzeit_B1[n] = P[0,n]
##    else:
##        endzeit_B1[n] = endzeit_B1[n-1] + P[0,n]
##    R[0,n] = 1  # Product is ready for Band 2
##    
##    # For Band 2
##    if n == 0:
##        endzeit_B2[n] = endzeit_B1[n] + P[1,n]
##    else:
##        endzeit_B2[n] = max(endzeit_B1[n], endzeit_B2[n-1]) + P[1,n]
##    R[1,n] = 1  # Product is ready for Band 3
##    
##    # For Band 3
##    if n == 0:
##        endzeit_B3[n] = endzeit_B2[n] + P[2,n]
##    else:
##        endzeit_B3[n] = max(endzeit_B2[n], endzeit_B3[n-1]) + P[2,n]

##gesamtzeit = endzeit_B3[-1]
##print(gesamtzeit)


def calculate_total_time(P):
    """
    Calculate the total time for products to pass through all bands.
    
    Parameters:
    - P: 2D numpy array where rows represent bands and columns represent products.
    
    Returns:
    - Total time for all products to pass through the last band.
    """
    
    num_bands, num_products = P.shape
    t = np.zeros((num_bands, num_products))
    
    # For the first band
    t[0, 0] = P[0, 0]
    for j in range(1, num_products):
        t[0, j] = t[0, j-1] + P[0, j]
        
    # For the subsequent bands
    for i in range(1, num_bands):
        t[i, 0] = t[i-1, 0] + P[i, 0]
        for j in range(1, num_products):
            t[i, j] = max(t[i-1, j], t[i, j-1]) + P[i, j]
            
    return t[num_bands-1, num_products-1]

# Test the function

a=calculate_total_time(P)
print(a)

