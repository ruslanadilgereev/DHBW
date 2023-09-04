import numpy as np
import matplotlib.pyplot as plt
import time

# P_pcs_time = np.array([[139, 729, 382, 382, 468, 814],  ## Stückzahl der Produkte
#                       [79,113, 78, 113, 46, 113],  ## Produktionszeit auf Band 1
#                       [43, 61, 42, 61,12,75], ## Produktionszeit auf Band 2
#                       [141,159,141,159,62,141], ## Produktionszeit auf Band 3
#                       [145,160,145,160,80,100]])  ## Produktionszeit auf Band 4)


P_pcs_time = np.array([ [1,2,3,3], ## Stückzahl der Produkte
                        [2,1,3,1], ## Produktionszeit auf Band 1
                        [5,1,2,1]])## Produktionszeit auf Band 2

def fitness_calc(P):
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

## Nicht anwendbar, da die Stückzahl bei der Crossover Methode nicht beachtet wird.
def single_point_crossover_1D(A, B, p):
    if p <= 0:
        p = np.random.randint(1,A.size)
    child1 = A##np.concatenate((A[:p], B[p:]))
    child2 = B##np.concatenate((B[:p], A[p:]))
    return child1, child2

def order_to_time(product_order):
    array = []
    n_band = P_pcs_time.shape[0] - 1

    # Create the processing time representation based on the given product order
    for j in range(n_band):
        for product_index in product_order:
            array.append(P_pcs_time[j + 1, product_index])

    # Convert the array to a 2D matrix
    time_matrix = np.array(array).reshape(-1, len(product_order))

    return time_matrix

def mutate(individuum, mutation_rate):
    """Mutation_Count gibt die Anzahl der Mutation an die stattfinden soll.
    Mutation_Rate gibt die Wahrscheinlichkeit an, dass eine Mutation stattfindet."""
    if np.random.rand() < mutation_rate:
        for i in range(mutation_count):
            # Wähle zwei zufällige Indizes zum Austauschen
            idx1, idx2 = np.random.randint(0, len(individuum), 2)
            # Tausche die Elemente an diesen Indizes
            individuum[idx1], individuum[idx2] = individuum[idx2], individuum[idx1]
    return individuum

if __name__ == "__main__":
    summe = 0
    start = time.time()
    generation_count = 100  # Anzahl der Generationen
    pop_count = 100          # Anzahl der Individuuen pro Population
    mutation_rate = 1     # Wahrscheinlichkeit für eine Mutation (zwischen 0 und 1)
    mutation_count = 5      # Anzahl der Mutationselemente
    top_individuals_ratio = 0.2  # Anteil der besten Individuen, die in die nächste Generation übernommen werden in % (zwischen 0 und 1)
    all_fit_values = []     # Liste, um die Fitnesswerte aller Individuen über alle Generationen zu speichern
    all_order_values = []   # Liste, um die Reihenfolge aller Individuen über alle Generationen zu speichern
    pop_order = {}
    pop_fitness = {}

    plt.ion()
    fig, ax = plt.subplots()
    # Anpassungen an der X- und Y-Achse, Titel, Legende usw.
    ax.set_xlabel('Individuum Nummer')
    ax.set_ylabel('Fitness')
    ax.set_title('Fitness über die Individuuen')
    ax.grid(True)
    line, = ax.plot([])     # Leerer Plot, der später aktualisiert wird

    """Greedy Verfahren"""
    sorted_P_pcs_time = np.argsort(P_pcs_time[1])
    sorted_M = P_pcs_time[:, sorted_P_pcs_time]
    # Extracting the repetition counts from the first row
    repetition_counts_first_row = sorted_M[0]
    greedy_order = [value for value, count in zip(sorted_P_pcs_time, repetition_counts_first_row) for _ in range(count)]
    print(f"Fitness mit Greedy Verfahren: {fitness_calc(order_to_time(greedy_order))}: {greedy_order}")
    """**************************"""

    """Startpopulation bilden"""
    for i in range(pop_count):
        ind_time, ind_order = generate_individuum(P_pcs_time)
        pop_fitness[i] = fitness_calc(ind_time)
        pop_order[i] = ind_order

    for generation in range(generation_count):
        # Sortieren aller Fitnesswerte dieser Population mit der Reihenfolge
        sorted_keys = sorted(pop_fitness, key = pop_fitness.get) # type: ignore
        sorted_pop_order = {key: pop_order[key] for key in sorted_keys}
        top_individuals = [sorted_pop_order[key] for key in sorted_keys[:int(pop_count * top_individuals_ratio)]]
        top_individuals_dict = {i: indiv for i, indiv in enumerate(top_individuals)}

        k = len(top_individuals_dict)
        while k < pop_count:
            i, j = np.random.randint(0, len(top_individuals_dict), size=2)
            child1, child2 = single_point_crossover_1D(top_individuals_dict[i],
                                                       top_individuals_dict[j],
                                                       np.random.randint(0, len(top_individuals_dict[0])-1))
            top_individuals_dict[k] = mutate(child1, mutation_rate)
            top_individuals_dict[k + 1] = mutate(child2, mutation_rate)
            k += 2

        for i in range(len(top_individuals_dict)):
            pop_order[i] = top_individuals_dict[i]
            current_fitness = fitness_calc(order_to_time(top_individuals_dict[i]))
            pop_fitness[i] = current_fitness
            all_fit_values.append((current_fitness, pop_order[i]))   # Add the current fitness value directly
            all_fit_values.sort(key=lambda x: x[0], reverse=True)   
            x_data = range(len(all_fit_values))                      # X-data for the plot
            y_data = [value[0] for value in all_fit_values]          # Extract the fitness values for Y-data
            line.set_xdata(x_data)                                   # Update X-data
            line.set_ydata(y_data)              # Y-Daten aktualisieren

        ax.relim()  # Grenzen neu berechnen
        ax.autoscale_view()  # Skaliert die Achse
        plt.draw()  # Zeichnet den aktualisierten Plot
        plt.pause(0.01)
    print(f"Fitness mit Genetischen Algorithmen: {all_fit_values[-1]}")
    plt.ioff()
    ende = time.time()
    print('{:5.3f}s'.format(ende - start))
    plt.show()
