/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        chili: { DEFAULT: '#C81E1E', dark: '#9A1515', light: '#E63A3A' },
        ember: { DEFAULT: '#F97316', light: '#FDBA74' },
        char: { DEFAULT: '#16110F', soft: '#231A17', line: '#3A2C27' },
        cream: '#FAF3EC',
      },
      fontFamily: {
        display: ['Anton', 'sans-serif'],
        body: ['"Plus Jakarta Sans"', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
