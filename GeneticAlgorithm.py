import numpy as np
import matplotlib.pyplot as plt

P_pcs_time = np.array([[139, 729, 382, 382, 468, 814],  ## Stückzahl der Produkte
                      [79,113, 78, 113, 46, 113],  ## Produktionszeit auf Band 1
                      [43, 61, 42, 61,12,75], ## Produktionszeit auf Band 2
                      [141,159,141,159,62,141], ## Produktionszeit auf Band 3
                      [145,160,145,160,80,100]])  ## Produktionszeit auf Band 4)

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


def single_point_crossover_1D(A, B, p):
    if p <= 0:
        p = np.random.randint(1,A.size)
    x = np.random.randint(0, p)
    child1 = np.concatenate((A[:x], B[x:]))
    child2 = np.concatenate((B[:x], A[x:]))
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
    generation_count = 100  # Anzahl der Generationen
    pop_count = 50          # Anzahl der Individuuen pro Population
    mutation_rate = 0.3     # Wahrscheinlichkeit für eine Mutation
    mutation_count = 5      # Anzahl der Mutationselemente

    all_fit_values = []     # Liste, um die Fitnesswerte aller Individuen über alle Generationen zu speichern
    pop_order = {}
    pop_fitness = {}

    plt.ion()
    fig, ax = plt.subplots()
    # Anpassungen an der X- und Y-Achse, Titel, Legende usw.
    ax.set_xlabel('Individuum Nummer')
    ax.set_ylabel('Fitness')
    ax.set_title('Fitness über die Generationen')
    ax.grid(True)
    line, = ax.plot([])     # Leerer Plot, der später aktualisiert wird

    for i in range(pop_count):
        ind_time, ind_order = generate_individuum(P_pcs_time)
        pop_fitness[i] = fitness_calc2(ind_time)
        pop_order[i] = ind_order

    for generation in range(generation_count):
        print(f"Generation: # {generation}")
        # Sortieren aller Fitnesswerte dieser Population mit der Reihenfolge
        sorted_keys = sorted(pop_fitness, key=pop_fitness.get)
        sorted_pop_order = {key: pop_order[key] for key in sorted_keys}
        top_individuals = [sorted_pop_order[key] for key in sorted_keys[:pop_count // 2]]
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
            current_fitness = fitness_calc2(order_to_time(top_individuals_dict[i]))
            pop_fitness[i] = current_fitness
            all_fit_values.append(current_fitness)      # Füge den aktuellen Fitnesswert direkt hinzu
            all_fit_values.sort(reverse=True)           # Sortieren der Liste - absteigend
            line.set_xdata(range(len(all_fit_values)))  # X-Daten aktualisieren
            line.set_ydata(all_fit_values)              # Y-Daten aktualisieren

        ax.relim()  # Grenzen neu berechnen
        ax.autoscale_view()  # Skaliert die Achse
        plt.draw()  # Zeichnet den aktualisierten Plot
        plt.pause(0.1)
    plt.ioff()
    plt.show()
