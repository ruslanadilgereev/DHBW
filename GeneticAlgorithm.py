import numpy as np
import matplotlib.pyplot as plt

P_pcs_time = np.array([[139, 729, 382, 382, 468, 814],  ## Stückzahl der Produkte
                       [79, 113, 79, 113, 46, 113],  ## Produktionszeit auf Band 1
                       [43,  62, 43, 62, 12, 75],
                       [141, 159, 141, 159, 62, 141],
                       [145, 160, 145, 160, 80, 100]])  ## Produktionszeit auf Band 2


##def fitness_calc1(P):
####### Erste Variante
##R = np.zeros((3,8))s
##endzeit_B1 = np.zeros(8)
##endzeit_B2 = np.zeros(8)
##endzeit_B3 = np.zeros(8)

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

def fitness_calc2(P):
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
        t[0, j] = t[0, j - 1] + P[0, j]

    # For the subsequent bands
    for i in range(1, num_bands):
        t[i, 0] = t[i - 1, 0] + P[i, 0]
        for j in range(1, num_products):
            t[i, j] = max(t[i - 1, j], t[i, j - 1]) + P[i, j]

    return t[num_bands - 1, num_products - 1]


def generate_individuum(P_pcs_time):
    # Create an empty list
    array = []
    n_band = P_pcs_time.shape[0] - 1

    # Create a product order list based on the quantity of each product
    product_order_list = []
    for i in range(P_pcs_time.shape[1]):
        product_order_list.extend([i] * P_pcs_time[0, i])

    # Shuffle the product order list to get the shuffled product order
    shuffled_product_order = np.random.permutation(product_order_list)

    # Create the shuffled processing time representation based on the shuffled product order
    for j in range(n_band):
        for product_index in shuffled_product_order:
            array.append(P_pcs_time[j + 1, product_index])

    # Convert the array to a 2D matrix
    shuffled_array = np.array(array).reshape(-1, len(shuffled_product_order))

    return shuffled_array, shuffled_product_order


def single_point_crossover(A, B):
    A_new = np.zeros(A.shape, dtype=int)
    B_new = np.zeros(B.shape, dtype=int)
    x = np.random.randint(1, A.shape[1])
    for i in range(A.shape[0]):
        A_new[i] = np.append(A[i, :x], B[i, x:])
        B_new[i] = np.append(B[i, :x], A[i, x:])
    return A_new, B_new


if __name__ == "__main__":
    generation = 0
    pop_count = 10000
    pop_fitness = {}
    pop_order = {}
    fit_value = []
    ##while generation < 100:
    for i in range(pop_count):
        ind_time, ind_code = generate_individuum(P_pcs_time)
        pop_fitness[i] = fitness_calc2(ind_time)
        pop_order[i] = ind_code

    sorted_keys = sorted(pop_fitness, key=pop_fitness.get, reverse=True)
    sorted_pop_fitness = {key: pop_fitness[key] for key in sorted_keys}
    sorted_pop_order = {key: pop_order[key] for key in sorted_keys}

    print(sorted_pop_order[9999])
    ##for i in range(pop_count):
    ##    fit_value.append(sorted_pop_fitness[i][1])
    ##print(fit_value)


    # Using seaborn to plot
    plt.figure(figsize=(10, 5))
    plt.plot(sorted_pop_fitness.values(), marker='o', linestyle='-', color='b')
    plt.title("Float Values")
    plt.xlabel("Index")
    plt.ylabel("Value")
    plt.grid(True)
    plt.show()
