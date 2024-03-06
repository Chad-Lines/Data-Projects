import pandas as pd
import nltk
from nltk.corpus import stopwords
from collections import Counter
import csv

# Download necessary tools from nltk
nltk.download('stopwords')
nltk.download('punkt')

# Read csv into a dataframe
df = pd.read_csv('ta.csv')

# Combine all titles and descriptions into a single text
all_text = ' '.join(df['title']) + ' ' + ' '.join(df['description'])

# Tokenize and remove stop words
words = nltk.word_tokenize(all_text)
filtered_words = [word for word in words if word.isalnum() and word not in stopwords.words('english')]

# Count and display most common words
word_counts = Counter(filtered_words)
common_words_df = pd.DataFrame(word_counts.most_common(10), columns=['Word', 'Count'])

# Save to csv
common_words_df.to_csv('common_words.csv', index=False)