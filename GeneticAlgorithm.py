import numpy as np
import matplotlib.pyplot as plt

P_pcs_time = np.array([[1,3,4,1], ## Stückzahl der Produkte
                       [4,2,4,5], ## Produktionszeit auf Band 1
                       [2,6,2,8]]) ## Produktionszeit auf Band 2

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
        t[0, j] = t[0, j-1] + P[0, j]
        
    # For the subsequent bands
    for i in range(1, num_bands):
        t[i, 0] = t[i-1, 0] + P[i, 0]
        for j in range(1, num_products):
            t[i, j] = max(t[i-1, j], t[i, j-1]) + P[i, j]
            
    return t[num_bands-1, num_products-1]

def generate_individuum(P_pcs_time):
    # Erstellen Sie ein leeres Array
    array = []
    n_band = P_pcs_time.shape[0]-1
    n_product = np.sum(P_pcs_time[0])

    # Durchlaufen Sie jedes Produkt (jede Spalte in P_pcs_time)
    for j in range(n_band):
        for i in range(P_pcs_time.shape[1]):
            # Verwenden Sie die Bearbeitungszeit des Produkts als Darstellung
            processing_time_representation = P_pcs_time[j+1, i]
            
            # Fügen Sie die Bearbeitungszeit-Darstellung entsprechend der Stückzahl des Produkts zum Array hinzu
            array.extend([processing_time_representation] * P_pcs_time[0, i])

    # Mischen Sie das Array, um es zufällig zu machen
    p_matrix = np.array(array).reshape(-1, n_product)

    # Generate shuffled column indices
    shuffled_indices = np.random.permutation(p_matrix.shape[1])

    # Use the shuffled indices to rearrange the columns
    shuffled_array = p_matrix[:, shuffled_indices]
    return shuffled_array

def single_point_crossover(A, B):
    A_new = np.zeros(A.shape,dtype=int)
    B_new = np.zeros(B.shape,dtype=int)
    x = np.random.randint(1, A.shape[1])
    for i in range(A.shape[0]):
        A_new[i] = np.append(A[i, :x], B[i, x:])
        B_new[i] = np.append(B[i, :x], A[i, x:])
    return A_new, B_new

if __name__ == "__main__":
    generation = 0
    pop_count = 20
    pop_fitness = {}
    fit_value = []
    ##while generation < 100:
    for i in range(pop_count):
        ind = generate_individuum(P_pcs_time)
        pop_fitness[i] = fitness_calc2(ind)

    sorted_pop_fitness = sorted(pop_fitness.items(), key=lambda x: x[1],reverse=True)

    for i in range(pop_count):
        fit_value.append(sorted_pop_fitness[i][1])



    # Using seaborn to plot
    plt.figure(figsize=(10, 5))
    plt.plot(fit_value, marker='o', linestyle='-', color='b')
    plt.title("Float Values")
    plt.xlabel("Index")
    plt.ylabel("Value")
    plt.grid(True)
    plt.show()